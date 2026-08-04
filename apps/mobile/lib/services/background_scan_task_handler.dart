import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_radio/unrecorded_radio.dart';

import '../features/scan/scan_state.dart';
import 'android_protection_protocol_store.dart';
import 'background_protection_snapshot.dart';
import 'background_risk_alert_notifier.dart';
import 'background_risk_episode.dart';
import 'background_scan_runtime.dart';
import 'protection_protocol_models.dart';
import 'protection_protocol_store.dart';
import 'protection_status_notification.dart';
import 'recent_risk_recording.dart';
import 'scan_lifecycle_coordinator.dart';
import 'scan_preflight_mapping.dart';
import 'scan_runtime.dart';
import 'signal_ui_mapper.dart';

/// Notification button id for the Stop action.
const kFgsStopButtonId = 'bg_stop';

// Top-level entry point required by flutter_foreground_task.
@pragma('vm:entry-point')
void backgroundScanTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_BackgroundScanTaskHandler());
}

// ---------------------------------------------------------------------------

class _BackgroundScanTaskHandler extends TaskHandler {
  _BackgroundScanTaskHandler({BackgroundScanTaskEngine? engine})
      : _engine = engine;

  BackgroundScanTaskEngine? _engine;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final engine = _engine ??
        BackgroundScanTaskEngine(
          storeFactory: AndroidProtectionProtocolStore.new,
          runtime: const BackgroundScanRuntime(),
          scannerFactory: BleRadioScanner.new,
          onSnapshot: (snapshot) {
            FlutterForegroundTask.sendDataToMain(snapshot.toJson());
          },
          requestStopService: () => FlutterForegroundTask.stopService(),
          updateNotification: (status) async {
            await FlutterForegroundTask.updateService(
              notificationTitle: AppCopy.backgroundProtectionNotificationTitle,
              notificationText: backgroundProtectionStatusBodyFor(status),
              notificationButtons: [
                const NotificationButton(
                  id: kFgsStopButtonId,
                  text: AppCopy.backgroundProtectionStopAction,
                ),
              ],
            );
          },
        );
    _engine = engine;
    await engine.start(starterName: starter.name);
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _engine?.destroy(isTimeout: isTimeout);
    _engine = null;
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == kFgsStopButtonId) {
      _engine?.onNotificationStopPressed();
    }
  }

  @override
  void onReceiveData(Object data) {
    _engine?.onReceiveData(data);
  }
}

/// Testable task-isolate protection engine (plan sections 9–10).
///
/// Owns protocol fail-closed startup, lease claim, readiness, material-risk
/// episodes, and notification Stop. Does not write legacy prefs.
class BackgroundScanTaskEngine {
  BackgroundScanTaskEngine({
    required ProtectionProtocolStore Function() storeFactory,
    required ScanRuntime runtime,
    required RadioScanner Function() scannerFactory,
    required void Function(BackgroundProtectionSnapshot snapshot) onSnapshot,
    required Future<void> Function() requestStopService,
    Future<void> Function(ScanStatus status)? updateNotification,
    ScannerMode Function()? scannerModeFactory,
    BackgroundRiskAlertNotifier? riskNotifier,
    this.commitStopTimeout = const Duration(seconds: 5),
    this.mechanicsStopTimeout = const Duration(seconds: 8),
  })  : _storeFactory = storeFactory,
        _runtime = runtime,
        _scannerFactory = scannerFactory,
        _onSnapshot = onSnapshot,
        _requestStopService = requestStopService,
        _updateNotification = updateNotification,
        _scannerModeFactory = scannerModeFactory ?? (() => ScannerMode.auto),
        _riskNotifier = riskNotifier ?? BackgroundRiskAlertNotifier();

  final ProtectionProtocolStore Function() _storeFactory;
  final ScanRuntime _runtime;
  final RadioScanner Function() _scannerFactory;
  final void Function(BackgroundProtectionSnapshot snapshot) _onSnapshot;
  final Future<void> Function() _requestStopService;
  final Future<void> Function(ScanStatus status)? _updateNotification;
  final ScannerMode Function() _scannerModeFactory;
  final BackgroundRiskAlertNotifier _riskNotifier;
  final Duration commitStopTimeout;
  final Duration mechanicsStopTimeout;

  final SignalUiMapper _mapper = const SignalUiMapper();
  final BackgroundRiskEpisodeTracker _episodes = BackgroundRiskEpisodeTracker();

  ProtectionProtocolStore? _store;
  StreamSubscription<ProtocolChangeNotification>? _protocolSub;
  ScanLifecycleCoordinator? _coordinator;

  String? _sessionId;
  int? _sessionEpoch;
  String? _engineIncarnationId;
  String? _scannerLeaseId;
  int _messageSequence = 0;
  var _serviceRunning = false;
  var _stopInProgress = false;
  var _startupCancelled = false;
  var _scannerReady = false;
  BackgroundProtectionStoppedReason? _terminalReason;
  ScanPreflightFailure? _terminalBlockedCause;
  StopTransactionOutcome? _terminalStopOutcome;
  int? _stopConfirmedRevision;
  String? _scannerStopOutcome;
  bool? _leaseReleased;
  ScanStatus? _previousStatus;
  BackgroundScannerPhase _scannerPhase = BackgroundScannerPhase.starting;

  /// Exposed for tests.
  bool get isScannerReady => _scannerReady;
  bool get stopInProgress => _stopInProgress;
  BackgroundProtectionStoppedReason? get terminalReason => _terminalReason;

  Future<void> start({String starterName = 'developer'}) async {
    _log('task started (starter=$starterName)');
    _serviceRunning = true;
    _scannerPhase = BackgroundScannerPhase.starting;

    late final ProtectionProtocolStore store;
    try {
      store = _storeFactory();
      _store = store;
      // Subscribe BEFORE the first authoritative read so a Stop fence raised
      // during startup cancels before scanner construction.
      _protocolSub = store.changes.listen(_onProtocolChanged);
      await store.ensureReady();
    } catch (e) {
      _log('protocol unavailable: $e');
      await _failClosedTerminal(
        reason: BackgroundProtectionStoppedReason.protocolUnavailable,
      );
      return;
    }

    final admitted = await _admitStartup(store);
    if (!admitted) return;

    if (_startupCancelled || _stopInProgress) {
      await _failClosedTerminal(
        reason: BackgroundProtectionStoppedReason.cancelledBeforeStart,
      );
      return;
    }

    final preflight = await _runtime.ensureAndroidReady();
    if (!preflight.isOk) {
      await _failClosedBlocked(preflight.failure!);
      return;
    }

    if (_startupCancelled || _stopInProgress) {
      await _failClosedTerminal(
        reason: BackgroundProtectionStoppedReason.cancelledBeforeStart,
      );
      return;
    }

    final claimed = await _claimLeaseAndIncarnation(store);
    if (!claimed) return;

    if (_startupCancelled || _stopInProgress) {
      await _releaseLeaseBestEffort();
      await _failClosedTerminal(
        reason: BackgroundProtectionStoppedReason.cancelledBeforeStart,
      );
      return;
    }

    final coordinator = ScanLifecycleCoordinator(
      scannerFactory: _scannerFactory,
      runtime: _runtime,
      scannerModeFactory: _scannerModeFactory,
    );
    coordinator.onStateChanged = _onCoordinatorState;
    _coordinator = coordinator;

    final startOutcome = await coordinator.startProtection();
    if (startOutcome.preflight != null) {
      await _releaseLeaseBestEffort();
      await _failClosedBlocked(startOutcome.preflight!);
      return;
    }

    final start = startOutcome.start;
    if (start is! RadioStarted) {
      _log('scanner start failed: $start');
      await _releaseLeaseBestEffort();
      await _failClosedTerminal(
        reason: BackgroundProtectionStoppedReason.blocked,
        blockedCause: ScanPreflightFailure.bluetoothOff,
        scannerPhase: BackgroundScannerPhase.blocked,
      );
      return;
    }

    if (_startupCancelled || _stopInProgress) {
      // Late success after cancellation: stop mechanics, release only if
      // stop confirms, emit terminal cancellation.
      final stop = await coordinator.pauseProtection();
      final confirmed = stop is RadioStopped || stop is RadioAlreadyStopped;
      if (confirmed) {
        await _releaseLeaseBestEffort();
      }
      await _failClosedTerminal(
        reason: BackgroundProtectionStoppedReason.cancelledBeforeStart,
        scannerStopOutcome: _radioStopWireName(stop),
        leaseReleased: confirmed,
      );
      return;
    }

    final leaseId = _scannerLeaseId;
    if (leaseId == null) {
      await coordinator.pauseProtection();
      await _failClosedTerminal(
        reason: BackgroundProtectionStoppedReason.protocolUnavailable,
      );
      return;
    }

    final markedActive = await store.markLeaseActive(leaseId: leaseId);
    if (!markedActive) {
      _log('markLeaseActive failed');
      final stop = await coordinator.pauseProtection();
      final confirmed = stop is RadioStopped || stop is RadioAlreadyStopped;
      if (confirmed) await _releaseLeaseBestEffort();
      await _failClosedTerminal(
        reason: BackgroundProtectionStoppedReason.protocolUnavailable,
        scannerStopOutcome: _radioStopWireName(stop),
        leaseReleased: confirmed,
      );
      return;
    }

    final stateAfterActive = await store.getState();
    final tupleAfterActive = stateAfterActive.tuple;
    if (tupleAfterActive == null ||
        stateAfterActive.persistenceUncertain ||
        stateAfterActive.stopFenceRaised) {
      final stop = await coordinator.pauseProtection();
      final confirmed = stop is RadioStopped || stop is RadioAlreadyStopped;
      if (confirmed) await _releaseLeaseBestEffort();
      await _failClosedTerminal(
        reason: BackgroundProtectionStoppedReason.cancelledBeforeStart,
        scannerStopOutcome: _radioStopWireName(stop),
        leaseReleased: confirmed,
      );
      return;
    }

    final ready = await store.markTaskScannerReady(
      expectedRevision: tupleAfterActive.revision,
      sessionId: _sessionId!,
      epoch: _sessionEpoch!,
      incarnationId: _engineIncarnationId!,
      leaseId: leaseId,
    );

    if (ready is! ProtocolCommitConfirmed) {
      _log('markTaskScannerReady failed: $ready');
      final stop = await coordinator.pauseProtection();
      final confirmed = stop is RadioStopped || stop is RadioAlreadyStopped;
      if (confirmed) await _releaseLeaseBestEffort();
      await _failClosedTerminal(
        reason: BackgroundProtectionStoppedReason.protocolUnavailable,
        scannerStopOutcome: _radioStopWireName(stop),
        leaseReleased: confirmed,
      );
      return;
    }

    _scannerReady = true;
    _scannerPhase = BackgroundScannerPhase.scanning;
    _log('protection started');
    _emitOwnershipSnapshot(
      status: ScanStatus.scanning,
      riskLevel: RiskLevel.low,
      score: 0,
      reasonLabels: const [],
      possibleRiskCount: 0,
      otherNearbyCount: 0,
      isDemoMode: coordinator.isDemoMode,
      protocolRevision: ready.tuple.revision,
    );
  }

  Future<bool> _admitStartup(ProtectionProtocolStore store) async {
    final ProtectionProtocolState state;
    try {
      state = await store.getState();
    } catch (e) {
      _log('getState failed: $e');
      await _failClosedTerminal(
        reason: BackgroundProtectionStoppedReason.protocolUnavailable,
      );
      return false;
    }

    if (state.persistenceUncertain || state.tuple == null) {
      _log('fail-closed: persistence uncertain / schema not ready');
      await _failClosedTerminal(
        reason: BackgroundProtectionStoppedReason.protocolUnavailable,
      );
      return false;
    }

    if (state.stopFenceRaised) {
      _log('fail-closed: stop fence raised');
      await _failClosedTerminal(
        reason: BackgroundProtectionStoppedReason.cancelledBeforeStart,
      );
      return false;
    }

    final tuple = state.tuple!;
    if (tuple.schemaVersion != kProtectionProtocolSchemaVersion) {
      _log('fail-closed: schema version ${tuple.schemaVersion}');
      await _failClosedTerminal(
        reason: BackgroundProtectionStoppedReason.protocolUnavailable,
      );
      return false;
    }

    if (tuple.explicitlyStopped ||
        !tuple.protectionEnabled ||
        !tuple.backgroundRuntimeEnabled) {
      _log(
        'fail-closed: intent '
        '(stopped=${tuple.explicitlyStopped} '
        'enabled=${tuple.protectionEnabled} '
        'runtime=${tuple.backgroundRuntimeEnabled})',
      );
      await _failClosedTerminal(
        reason: tuple.explicitlyStopped
            ? BackgroundProtectionStoppedReason.explicitNotificationStop
            : BackgroundProtectionStoppedReason.none,
      );
      return false;
    }

    final sessionId = tuple.activeTaskSessionId;
    final epoch = tuple.activeTaskEpoch;
    if (sessionId == null || epoch == null) {
      _log('fail-closed: null session');
      await _failClosedTerminal(
        reason: BackgroundProtectionStoppedReason.cancelledBeforeStart,
      );
      return false;
    }

    if (tuple.taskPhase != ProtocolTaskPhase.allocated &&
        tuple.taskPhase != ProtocolTaskPhase.scannerReady) {
      _log('fail-closed: task phase ${tuple.taskPhase.wireName}');
      await _failClosedTerminal(
        reason: BackgroundProtectionStoppedReason.cancelledBeforeStart,
      );
      return false;
    }

    _sessionId = sessionId;
    _sessionEpoch = epoch;
    _engineIncarnationId = state.engineIncarnationId;
    return true;
  }

  Future<bool> _claimLeaseAndIncarnation(ProtectionProtocolStore store) async {
    // Reread before claim so a Stop during preflight is observed.
    final state = await store.getState();
    if (state.persistenceUncertain ||
        state.stopFenceRaised ||
        state.tuple == null) {
      await _failClosedTerminal(
        reason: BackgroundProtectionStoppedReason.cancelledBeforeStart,
      );
      return false;
    }
    final tuple = state.tuple!;
    if (tuple.activeTaskSessionId != _sessionId ||
        tuple.activeTaskEpoch != _sessionEpoch ||
        !tuple.backgroundRuntimeEnabled ||
        tuple.explicitlyStopped ||
        !tuple.protectionEnabled) {
      await _failClosedTerminal(
        reason: BackgroundProtectionStoppedReason.cancelledBeforeStart,
      );
      return false;
    }

    final incarnationId = state.engineIncarnationId;
    _engineIncarnationId = incarnationId;

    final claim = await store.claimTaskIncarnation(
      expectedRevision: tuple.revision,
      sessionId: _sessionId!,
      incarnationId: incarnationId,
    );
    if (claim is! ProtocolCommitConfirmed) {
      _log('claimTaskIncarnation rejected: $claim');
      await _failClosedTerminal(
        reason: BackgroundProtectionStoppedReason.cancelledBeforeStart,
      );
      return false;
    }

    final leaseResult = await store.acquireTaskLease(
      sessionId: _sessionId!,
      epoch: _sessionEpoch!,
      incarnationId: incarnationId,
    );
    if (leaseResult is! ScannerLeaseAcquired) {
      _log('acquireTaskLease rejected: $leaseResult');
      await _failClosedTerminal(
        reason: BackgroundProtectionStoppedReason.cancelledBeforeStart,
      );
      return false;
    }

    _scannerLeaseId = leaseResult.lease.leaseId;
    return true;
  }

  void _onProtocolChanged(ProtocolChangeNotification _) {
    unawaited(_recheckProtocolCancellation());
  }

  Future<void> _recheckProtocolCancellation() async {
    final store = _store;
    if (store == null || _stopInProgress) return;
    try {
      final state = await store.getState();
      if (state.stopFenceRaised ||
          state.persistenceUncertain ||
          (state.tuple?.explicitlyStopped ?? false) ||
          !(state.tuple?.protectionEnabled ?? false) ||
          !(state.tuple?.backgroundRuntimeEnabled ?? false) ||
          state.tuple?.activeTaskSessionId != _sessionId) {
        _startupCancelled = true;
        if (_scannerReady && !_stopInProgress) {
          // Runtime revoked after ready — treat as external stop fence.
          unawaited(_handleExplicitStop(fromNotification: false));
        }
      }
    } catch (_) {
      _startupCancelled = true;
    }
  }

  void _onCoordinatorState(ScanState state, PipelineResult pipelineResult) {
    if (_stopInProgress || !_scannerReady) return;

    final (risk, other) =
        _mapper.partition(pipelineResult.snapshot.assessments);

    final isLiveRisk = state.status == ScanStatus.possibleRiskDetected;
    final episode = _episodes.update(
      assessments: pipelineResult.snapshot.assessments,
      riskLevel: pipelineResult.scoring.level,
      isLiveRisk: isLiveRisk,
    );

    _scannerPhase = switch (state.status) {
      ScanStatus.resting || ScanStatus.confirmingRisk =>
        BackgroundScannerPhase.resting,
      ScanStatus.possibleRiskDetected || ScanStatus.scanning =>
        BackgroundScannerPhase.scanning,
      _ => _scannerPhase,
    };

    _emitOwnershipSnapshot(
      status: state.status,
      riskLevel: pipelineResult.scoring.level,
      score: pipelineResult.scoring.totalScore,
      reasonLabels: pipelineResult.scoring.reasons,
      possibleRiskCount: risk.length,
      otherNearbyCount: other.length,
      lastCheckedAt: pipelineResult.snapshot.capturedAt,
      isDemoMode: _coordinator?.isDemoMode ?? false,
      riskEpisodeId: episode?.riskEpisodeId,
    );

    unawaited(_safeUpdateNotification(state.status));

    if (_previousStatus != ScanStatus.possibleRiskDetected &&
        state.status == ScanStatus.possibleRiskDetected) {
      unawaited(
        recordRecentRiskFromBackground(
          riskLevel: pipelineResult.scoring.level,
          assessments: pipelineResult.snapshot.assessments,
        ),
      );
      unawaited(
        _riskNotifier.showRiskAlertIfEnabled(
          riskLevel: pipelineResult.scoring.level,
        ),
      );
    }
    _previousStatus = state.status;
  }

  void onNotificationStopPressed() {
    _log('Stop button pressed from notification');
    unawaited(_handleExplicitStop(fromNotification: true));
  }

  Future<void> _handleExplicitStop({required bool fromNotification}) async {
    if (_stopInProgress) return;
    _stopInProgress = true;
    _startupCancelled = true;
    _scannerPhase = BackgroundScannerPhase.stopping;
    _terminalReason =
        BackgroundProtectionStoppedReason.explicitNotificationStop;

    // fromNotification distinguishes button vs protocol fence for logs only.
    _log(
      fromNotification
          ? 'explicit Stop from notification'
          : 'explicit Stop from protocol fence',
    );

    // Prevent further risk alerts immediately.
    unawaited(_riskNotifier.cancelRiskAlert());
    _episodes.clear();

    final store = _store;
    final commitFuture = store == null
        ? Future<ProtocolCommitResult>.value(
            const ProtocolCommitRejected(
              reason: ProtocolRejectReason.guardFailed,
              current: null,
            ),
          )
        : store.commitExplicitStop();

    final mechanicsFuture = _shutdownMechanics();

    ProtocolCommitResult? commitResult;
    try {
      commitResult = await commitFuture.timeout(commitStopTimeout);
    } on TimeoutException {
      commitResult = null;
    } catch (e) {
      _log('commitExplicitStop failed: $e');
      commitResult = null;
    }

    RadioStopResult? stopResult;
    try {
      stopResult = await mechanicsFuture.timeout(mechanicsStopTimeout);
    } on TimeoutException {
      stopResult = null;
    } catch (e) {
      _log('mechanics stop failed: $e');
      stopResult = null;
    }

    final stopOutcome = switch (commitResult) {
      ProtocolCommitConfirmed(:final tuple) => () {
          _stopConfirmedRevision = tuple.revision;
          return StopTransactionOutcome.confirmed;
        }(),
      ProtocolCommitPersistenceUncertain() =>
        StopTransactionOutcome.persistenceUncertain,
      ProtocolCommitRejected() || ProtocolCommitStale() =>
        StopTransactionOutcome.rejected,
      null => StopTransactionOutcome.persistenceUncertain,
    };
    _terminalStopOutcome = stopOutcome;
    _scannerStopOutcome = _radioStopWireName(stopResult);

    final stopConfirmed =
        stopResult is RadioStopped || stopResult is RadioAlreadyStopped;
    if (stopConfirmed) {
      _leaseReleased = await _releaseLeaseBestEffort();
    } else {
      _leaseReleased = false;
    }

    _serviceRunning = false;
    _scannerPhase = BackgroundScannerPhase.stopped;
    _scannerReady = false;

    _emitStopSnapshot(
      stopTransactionOutcome: stopOutcome,
    );

    try {
      await _requestStopService();
    } catch (e) {
      _log('stopService failed: $e');
    }
  }

  Future<RadioStopResult?> _shutdownMechanics() async {
    final coordinator = _coordinator;
    _coordinator = null;
    if (coordinator == null) {
      return const RadioAlreadyStopped();
    }
    return coordinator.pauseProtection();
  }

  Future<bool> _releaseLeaseBestEffort() async {
    final store = _store;
    final leaseId = _scannerLeaseId;
    if (store == null) return false;
    try {
      if (leaseId != null) {
        return await store.releaseLease(leaseId: leaseId);
      }
      return await store.releaseLeaseForEngine();
    } catch (e) {
      _log('releaseLease failed: $e');
      return false;
    }
  }

  Future<void> destroy({required bool isTimeout}) async {
    _log('task destroyed (isTimeout=$isTimeout)');
    _serviceRunning = false;
    await _riskNotifier.cancelRiskAlert();

    if (!_stopInProgress) {
      await _shutdownMechanics();
    }
    _coordinator = null;

    // Preserve blocked / explicit-stop causes; do not overwrite.
    final preserved = _terminalReason;
    final stoppedReason = preserved ??
        (isTimeout
            ? BackgroundProtectionStoppedReason.stoppedByAndroid
            : BackgroundProtectionStoppedReason.stoppedByAndroid);

    if (preserved == null) {
      _terminalReason = stoppedReason;
    }

    _scannerPhase = BackgroundScannerPhase.stopped;
    _emitDestroySnapshot(stoppedReason: _terminalReason!);

    await _protocolSub?.cancel();
    _protocolSub = null;
    await _store?.dispose();
    _store = null;
  }

  void onReceiveData(Object data) {
    if (data is! Map) return;
    final type = data['type'];
    if (type == 'test_risk_alert') {
      _log('test risk alert requested');
      unawaited(_riskNotifier.showTestAlert());
      return;
    }
    if (type == 'statusRequest') {
      _handleStatusRequest(data);
    }
  }

  void _handleStatusRequest(Map data) {
    if (!_scannerReady || _stopInProgress) return;
    final sessionId = data['sessionId'] as String?;
    final epoch = (data['epoch'] as num?)?.toInt();
    if (sessionId != _sessionId || epoch != _sessionEpoch) return;
    if (!_hasOwnershipIdentity) return;

    _emitOwnershipSnapshot(
      status: _previousStatus ?? ScanStatus.scanning,
      riskLevel: RiskLevel.low,
      score: 0,
      reasonLabels: const [],
      possibleRiskCount: 0,
      otherNearbyCount: 0,
      isDemoMode: _coordinator?.isDemoMode ?? false,
      riskEpisodeId: _episodes.current?.riskEpisodeId,
    );
  }

  Future<void> _failClosedBlocked(ScanPreflightFailure failure) async {
    _terminalBlockedCause = failure;
    await _failClosedTerminal(
      reason: BackgroundProtectionStoppedReason.blocked,
      blockedCause: failure,
      scannerPhase: BackgroundScannerPhase.blocked,
    );
  }

  Future<void> _failClosedTerminal({
    required BackgroundProtectionStoppedReason reason,
    ScanPreflightFailure? blockedCause,
    BackgroundScannerPhase scannerPhase = BackgroundScannerPhase.stopped,
    String? scannerStopOutcome,
    bool? leaseReleased,
  }) async {
    _serviceRunning = false;
    _scannerReady = false;
    _scannerPhase = scannerPhase;
    _terminalReason ??= reason;
    if (blockedCause != null) {
      _terminalBlockedCause ??= blockedCause;
    }
    if (scannerStopOutcome != null) {
      _scannerStopOutcome = scannerStopOutcome;
    }
    if (leaseReleased != null) {
      _leaseReleased = leaseReleased;
    }

    _emitTerminalSnapshot();
    try {
      await _requestStopService();
    } catch (e) {
      _log('stopService failed: $e');
    }
  }

  bool get _hasOwnershipIdentity =>
      _sessionId != null &&
      _sessionEpoch != null &&
      _engineIncarnationId != null &&
      _scannerLeaseId != null;

  void _emitOwnershipSnapshot({
    required ScanStatus status,
    required RiskLevel riskLevel,
    required int score,
    required List<String> reasonLabels,
    required int possibleRiskCount,
    required int otherNearbyCount,
    required bool isDemoMode,
    DateTime? lastCheckedAt,
    int? protocolRevision,
    String? riskEpisodeId,
  }) {
    // Never emit ownership-capable null-session snapshots.
    if (!_hasOwnershipIdentity) {
      _log('skip ownership snapshot: incomplete identity');
      return;
    }
    _messageSequence += 1;
    _onSnapshot(
      BackgroundProtectionSnapshot(
        status: status,
        riskLevel: riskLevel,
        score: score,
        reasonLabels: reasonLabels,
        possibleRiskCount: possibleRiskCount,
        otherNearbyCount: otherNearbyCount,
        lastCheckedAt: lastCheckedAt,
        isDemoMode: isDemoMode,
        serviceRunning: _serviceRunning,
        sessionId: _sessionId,
        sessionEpoch: _sessionEpoch,
        engineIncarnationId: _engineIncarnationId,
        scannerLeaseId: _scannerLeaseId,
        protocolRevision: protocolRevision,
        messageSequence: _messageSequence,
        scannerPhase: _scannerPhase,
        riskEpisodeId: riskEpisodeId,
      ),
    );
  }

  void _emitStopSnapshot({
    required StopTransactionOutcome stopTransactionOutcome,
  }) {
    // If identity was never recovered, emit a non-ownership diagnostic only.
    if (!_hasOwnershipIdentity) {
      _messageSequence += 1;
      _onSnapshot(
        BackgroundProtectionSnapshot(
          status: ScanStatus.paused,
          riskLevel: RiskLevel.low,
          score: 0,
          reasonLabels: const [],
          possibleRiskCount: 0,
          otherNearbyCount: 0,
          isDemoMode: false,
          serviceRunning: false,
          stoppedReason:
              BackgroundProtectionStoppedReason.explicitNotificationStop,
          messageSequence: _messageSequence,
          scannerPhase: BackgroundScannerPhase.stopped,
          stopTransactionOutcome: stopTransactionOutcome,
          stopConfirmedRevision: _stopConfirmedRevision,
          scannerStopOutcome: _scannerStopOutcome,
          leaseReleased: _leaseReleased,
        ),
      );
      return;
    }

    _messageSequence += 1;
    _onSnapshot(
      BackgroundProtectionSnapshot(
        status: ScanStatus.paused,
        riskLevel: RiskLevel.low,
        score: 0,
        reasonLabels: const [],
        possibleRiskCount: 0,
        otherNearbyCount: 0,
        isDemoMode: false,
        serviceRunning: false,
        stoppedReason:
            BackgroundProtectionStoppedReason.explicitNotificationStop,
        sessionId: _sessionId,
        sessionEpoch: _sessionEpoch,
        engineIncarnationId: _engineIncarnationId,
        scannerLeaseId: _scannerLeaseId,
        messageSequence: _messageSequence,
        scannerPhase: BackgroundScannerPhase.stopped,
        stopTransactionOutcome: stopTransactionOutcome,
        stopConfirmedRevision: _stopConfirmedRevision,
        scannerStopOutcome: _scannerStopOutcome,
        leaseReleased: _leaseReleased,
      ),
    );
  }

  void _emitTerminalSnapshot() {
    final reason =
        _terminalReason ?? BackgroundProtectionStoppedReason.protocolUnavailable;

    // Ownership-capable only when full identity is present.
    final canOwn = _hasOwnershipIdentity;
    if (canOwn) {
      _messageSequence += 1;
    }

    _onSnapshot(
      BackgroundProtectionSnapshot(
        status: _terminalBlockedCause != null
            ? scanStatusForPreflightFailure(_terminalBlockedCause!)
            : ScanStatus.paused,
        riskLevel: RiskLevel.low,
        score: 0,
        reasonLabels: const [],
        possibleRiskCount: 0,
        otherNearbyCount: 0,
        isDemoMode: false,
        serviceRunning: false,
        stoppedReason: reason,
        sessionId: canOwn ? _sessionId : null,
        sessionEpoch: canOwn ? _sessionEpoch : null,
        engineIncarnationId: canOwn ? _engineIncarnationId : null,
        scannerLeaseId: canOwn ? _scannerLeaseId : null,
        messageSequence: canOwn ? _messageSequence : null,
        scannerPhase: _scannerPhase,
        taskBlockedCause: _terminalBlockedCause,
        stopTransactionOutcome: _terminalStopOutcome,
        stopConfirmedRevision: _stopConfirmedRevision,
        scannerStopOutcome: _scannerStopOutcome,
        leaseReleased: _leaseReleased,
      ),
    );
  }

  void _emitDestroySnapshot({
    required BackgroundProtectionStoppedReason stoppedReason,
  }) {
    final canOwn = _hasOwnershipIdentity;
    if (canOwn) {
      _messageSequence += 1;
    }
    _onSnapshot(
      BackgroundProtectionSnapshot(
        status: ScanStatus.paused,
        riskLevel: RiskLevel.low,
        score: 0,
        reasonLabels: const [],
        possibleRiskCount: 0,
        otherNearbyCount: 0,
        isDemoMode: false,
        serviceRunning: false,
        stoppedReason: stoppedReason,
        sessionId: canOwn ? _sessionId : null,
        sessionEpoch: canOwn ? _sessionEpoch : null,
        engineIncarnationId: canOwn ? _engineIncarnationId : null,
        scannerLeaseId: canOwn ? _scannerLeaseId : null,
        messageSequence: canOwn ? _messageSequence : null,
        scannerPhase: BackgroundScannerPhase.stopped,
        taskBlockedCause: _terminalBlockedCause,
        stopTransactionOutcome: _terminalStopOutcome,
        stopConfirmedRevision: _stopConfirmedRevision,
        scannerStopOutcome: _scannerStopOutcome,
        leaseReleased: _leaseReleased,
      ),
    );
  }

  Future<void> _safeUpdateNotification(ScanStatus status) async {
    final update = _updateNotification;
    if (!_serviceRunning || update == null) return;
    try {
      await update(status);
    } catch (e) {
      _log('notification update failed: $e');
    }
  }

  String? _radioStopWireName(RadioStopResult? result) {
    return switch (result) {
      RadioStopped() => 'stopped',
      RadioAlreadyStopped() => 'alreadyStopped',
      RadioStopFailed(:final mayStillBeScanning) =>
        mayStillBeScanning ? 'failedMayStillScanning' : 'failed',
      null => 'timeoutOrError',
    };
  }

  void _log(String message) {
    if (kDebugMode || kProfileMode) {
      debugPrint('[BackgroundScanTask] $message');
    }
  }
}
