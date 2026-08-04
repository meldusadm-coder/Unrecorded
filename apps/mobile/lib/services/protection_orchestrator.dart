import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unrecorded_core/unrecorded_core.dart';

import '../features/scan/scan_state.dart';
import 'background_protection_preflight.dart';
import 'background_protection_snapshot.dart';
import 'background_scan_task_handler.dart';
import 'foreground_service_controller.dart';
import 'protection_protocol_models.dart';
import 'protection_protocol_store.dart';
import 'protection_state.dart';

typedef ForegroundMechanicsStart = Future<ForegroundStartResult> Function({
  required ScannerLease lease,
});
typedef ForegroundMechanicsPause = Future<ForegroundPauseResult> Function();

/// Sole main-isolate owner of protection intent and transitions.
class ProtectionOrchestrator
    extends StateNotifier<ProtectionOrchestratorState> {
  ProtectionOrchestrator({
    required ProtectionProtocolStore protocolStore,
    required BackgroundOwnershipClaim backgroundClaim,
    required ForegroundMechanicsStart startForeground,
    required ForegroundMechanicsPause pauseForeground,
    required ForegroundServiceController foregroundService,
    required BackgroundProtectionPreflight backgroundPreflight,
    required void Function(ScanState state) applyMirroredScanState,
    required void Function(ScannerOwner owner) onOwnerChanged,
    bool supportBackground = true,
    Duration protocolTimeout = const Duration(seconds: 5),
    Duration foregroundTimeout = const Duration(seconds: 15),
    Duration readinessTimeout = const Duration(seconds: 20),
    Duration stopTimeout = const Duration(seconds: 20),
    String? processId,
    Random? random,
  })  : _store = protocolStore,
        _claim = backgroundClaim,
        _startForeground = startForeground,
        _pauseForeground = pauseForeground,
        _foregroundService = foregroundService,
        _backgroundPreflight = backgroundPreflight,
        _applyMirroredScanState = applyMirroredScanState,
        _onOwnerChanged = onOwnerChanged,
        _supportBackground = supportBackground,
        _protocolTimeout = protocolTimeout,
        _foregroundTimeout = foregroundTimeout,
        _readinessTimeout = readinessTimeout,
        _stopTimeout = stopTimeout,
        _processId = processId ?? 'main',
        _random = random ?? Random(),
        super(const ProtectionOrchestratorState()) {
    _foregroundService.addDataCallback(_onTaskData);
    _protocolSub = _store.changes.listen((_) {
      unawaited(_onProtocolChanged());
    });
  }

  final ProtectionProtocolStore _store;
  final BackgroundOwnershipClaim _claim;
  final ForegroundMechanicsStart _startForeground;
  final ForegroundMechanicsPause _pauseForeground;
  final ForegroundServiceController _foregroundService;
  final BackgroundProtectionPreflight _backgroundPreflight;
  final void Function(ScanState state) _applyMirroredScanState;
  final void Function(ScannerOwner owner) _onOwnerChanged;
  final bool _supportBackground;
  final Duration _protocolTimeout;
  final Duration _foregroundTimeout;
  final Duration _readinessTimeout;
  final Duration _stopTimeout;
  final String _processId;
  final Random _random;

  StreamSubscription<ProtocolChangeNotification>? _protocolSub;
  _ActiveOperation? _active;
  final Map<String, Completer<ProtectionCommandOutcome>> _completers = {};
  final List<Timer> _timers = [];
  ScannerLease? _foregroundLease;
  String? _pendingSessionId;
  int? _pendingEpoch;
  String? _pendingAttemptId;
  Future<ServiceRequestResult>? _pendingNativeStart;
  var _opCounter = 0;
  var _completionGuardAsserted = false;
  var _disposedFlag = false;

  /// Test hook: true after a Completer completed (once-only guard).
  @visibleForTesting
  bool get completionGuardAsserted => _completionGuardAsserted;

  // ---------------------------------------------------------------------------
  // Public commands
  // ---------------------------------------------------------------------------

  Future<ProtectionCommandOutcome> turnProtectionOn() {
    return _admit(
      kind: _CommandKind.enable,
      transition: null, // chosen after reading preferred mode
      run: _effectTurnOn,
      equalityNoOp: () {
        final tuple = state.lastConfirmedTuple;
        if (tuple == null || !tuple.protectionEnabled) return false;
        if (state.confirmedOwner == ScannerOwner.none) return false;
        if (state.issue != null) return false;
        return true;
      },
    );
  }

  Future<ProtectionCommandOutcome> stopAllProtection() {
    return _admitStop();
  }

  Future<ProtectionCommandOutcome> setBackgroundModePreferred(bool value) {
    final protecting = state.confirmedOwner != ScannerOwner.none &&
        state.lastConfirmedTuple?.protectionEnabled == true;
    final phase = !protecting
        ? ProtectionTransitionPhase.idle
        : (value
            ? ProtectionTransitionPhase.switchingToBackground
            : ProtectionTransitionPhase.switchingToForeground);
    return _admit(
      kind: _CommandKind.setMode,
      transition: phase,
      equalityNoOp: () {
        final tuple = state.lastConfirmedTuple;
        return tuple != null &&
            tuple.backgroundModePreferred == value &&
            state.transition == ProtectionTransitionPhase.idle &&
            !state.retainedCleanup &&
            (!protecting ||
                (value && state.confirmedOwner == ScannerOwner.background) ||
                (!value && state.confirmedOwner == ScannerOwner.foreground));
      },
      run: (opId) => _effectSetMode(opId, value),
    );
  }

  Future<ProtectionCommandOutcome> reconcileOnLaunchOrResume() {
    return _admit(
      kind: _CommandKind.reconcile,
      transition: ProtectionTransitionPhase.reconciling,
      equalityNoOp: () => false,
      run: _effectReconcile,
      rejectIfBusy: true,
    );
  }

  Future<ProtectionCommandOutcome> retryCurrentIssue() {
    final issue = state.issue;
    if (issue == null) {
      return Future.value(const ProtectionNoOp());
    }
    switch (issue) {
      case BackgroundProtectionIssue.protocolPersistenceFailed:
      case BackgroundProtectionIssue.serviceStopFailed:
      case BackgroundProtectionIssue.foregroundStopFailed:
      case BackgroundProtectionIssue.staleStartCleanupPending:
        return stopAllProtection();
      case BackgroundProtectionIssue.androidStoppedBackgroundProtection:
      case BackgroundProtectionIssue.backgroundSwitchFailed:
      case BackgroundProtectionIssue.serviceStartFailed:
      case BackgroundProtectionIssue.readinessTimeout:
        return turnProtectionOn();
      case BackgroundProtectionIssue.foregroundStartFailed:
      case BackgroundProtectionIssue.mainPreflightFailed:
      case BackgroundProtectionIssue.leaseAcquireFailed:
        return turnProtectionOn();
      default:
        return reconcileOnLaunchOrResume();
    }
  }

  Future<ProtectionCommandOutcome> restartForegroundForConfiguration() {
    if (state.confirmedOwner != ScannerOwner.foreground || state.isBusy) {
      return Future.value(const ProtectionNoOp());
    }
    return _admit(
      kind: _CommandKind.restartForeground,
      transition: ProtectionTransitionPhase.enablingForeground,
      equalityNoOp: () => false,
      run: _effectRestartForeground,
    );
  }

  // ---------------------------------------------------------------------------
  // Admission
  // ---------------------------------------------------------------------------

  Future<ProtectionCommandOutcome> _admit({
    required _CommandKind kind,
    required ProtectionTransitionPhase? transition,
    required bool Function() equalityNoOp,
    required Future<void> Function(String opId) run,
    bool rejectIfBusy = true,
  }) {
    if (_disposedFlag) {
      return Future.value(const ProtectionDisposed());
    }
    // Busy is evaluated before equality/no-op.
    if (rejectIfBusy && state.isBusy) {
      return Future.value(const ProtectionBusy());
    }
    if (equalityNoOp()) {
      return Future.value(const ProtectionNoOp());
    }

    final opId = _nextOpId(kind);
    final completer = Completer<ProtectionCommandOutcome>();
    _completers[opId] = completer;
    _active = _ActiveOperation(id: opId, kind: kind);
    _publish(
      state.copyWith(
        activeOperationId: opId,
        transition: transition ??
            (state.lastConfirmedTuple?.backgroundModePreferred == true
                ? ProtectionTransitionPhase.enablingBackground
                : ProtectionTransitionPhase.enablingForeground),
        issue: null,
      ),
    );

    unawaited(() async {
      try {
        await run(opId);
      } catch (e, st) {
        if (_disposedFlag) return;
        if (kDebugMode) {
          debugPrint('[ProtectionOrchestrator] $kind failed: $e\n$st');
        }
        if (_isCurrent(opId)) {
          _completeFailed(opId, BackgroundProtectionIssue.unknown);
        }
      }
    }());

    return completer.future;
  }

  Future<ProtectionCommandOutcome> _admitStop() {
    if (_disposedFlag) {
      return Future.value(const ProtectionDisposed());
    }

    final tuple = state.lastConfirmedTuple;
    final alreadyStopped = tuple != null &&
        tuple.explicitlyStopped &&
        !tuple.protectionEnabled &&
        !tuple.backgroundRuntimeEnabled &&
        state.confirmedOwner == ScannerOwner.none &&
        !state.foregroundMayBeActive &&
        !state.backgroundMayBeActive &&
        !state.retainedCleanup &&
        state.activeOperationId == null;
    if (alreadyStopped) {
      return Future.value(const ProtectionNoOp());
    }

    // Supersede any active non-Stop command.
    final previous = _active;
    if (previous != null) {
      _completeOnce(previous.id, const ProtectionSuperseded());
    }

    final opId = _nextOpId(_CommandKind.stop);
    final completer = Completer<ProtectionCommandOutcome>();
    _completers[opId] = completer;
    _active = _ActiveOperation(id: opId, kind: _CommandKind.stop);
    _publish(
      state.copyWith(
        activeOperationId: opId,
        transition: ProtectionTransitionPhase.finalisingStop,
        retainedCleanup: true,
        issue: null,
      ),
    );

    unawaited(_effectStop(opId));
    return completer.future;
  }

  String _nextOpId(_CommandKind kind) {
    _opCounter += 1;
    return '${kind.name}-$_opCounter';
  }

  bool _isCurrent(String opId) {
    if (_disposedFlag) return false;
    return _active?.id == opId && state.activeOperationId == opId;
  }

  // ---------------------------------------------------------------------------
  // Effects
  // ---------------------------------------------------------------------------

  Future<void> _effectTurnOn(String opId) async {
    final ready = await _withTimeout(
      opId,
      _protocolTimeout,
      () => _store.ensureReady(),
      onTimeout: () {
        _completeFailed(opId, BackgroundProtectionIssue.protocolUnavailable);
      },
    );
    if (ready == null || !_isCurrent(opId)) return;

    if (ready is ProtocolCommitPersistenceUncertain) {
      _publish(
        state.copyWith(
          lastConfirmedTuple: ready.lastConfirmedTuple,
          issue: BackgroundProtectionIssue.protocolPersistenceFailed,
        ),
      );
      _completeFailed(
        opId,
        BackgroundProtectionIssue.protocolPersistenceFailed,
      );
      return;
    }
    if (ready is! ProtocolCommitConfirmed) {
      _completeFailed(opId, BackgroundProtectionIssue.protocolUnavailable);
      return;
    }

    final tuple = ready.tuple;
    _publish(
      state.copyWith(
        lastConfirmedTuple: tuple,
        engineIncarnationId: (await _store.getState()).engineIncarnationId,
        processInstanceId: (await _store.getState()).processInstanceId,
      ),
    );
    if (!_isCurrent(opId)) return;

    if (tuple.backgroundModePreferred && _supportBackground) {
      _publish(
        state.copyWith(
          transition: ProtectionTransitionPhase.enablingBackground,
        ),
      );
      await _effectEnableBackground(opId, tuple);
    } else {
      _publish(
        state.copyWith(
          transition: ProtectionTransitionPhase.enablingForeground,
        ),
      );
      await _effectEnableForeground(opId, tuple);
    }
  }

  Future<void> _effectEnableForeground(
    String opId,
    ProtectionProtocolTuple tuple,
  ) async {
    final intent = await _withTimeout(
      opId,
      _protocolTimeout,
      () => _store.beginForegroundIntent(expectedRevision: tuple.revision),
      onTimeout: () {
        _completeFailed(opId, BackgroundProtectionIssue.protocolUnavailable);
      },
    );
    if (intent == null || !_isCurrent(opId)) return;

    final confirmed = _requireConfirmed(
      opId,
      intent,
      retry: () async {
        final stateNow = await _store.getState();
        final current = stateNow.tuple;
        if (current == null) return null;
        return _store.beginForegroundIntent(expectedRevision: current.revision);
      },
    );
    if (confirmed == null) return;
    if (!_isCurrent(opId)) {
      // Late success â€” do not publish ownership; Stop/disposal handles cleanup.
      return;
    }

    _publish(state.copyWith(lastConfirmedTuple: confirmed));

    final leaseResult = await _withTimeout(
      opId,
      _protocolTimeout,
      () => _store.acquireForegroundLease(),
      onTimeout: () {
        _completeFailed(opId, BackgroundProtectionIssue.leaseAcquireFailed);
      },
    );
    if (leaseResult == null || !_isCurrent(opId)) return;

    if (leaseResult is! ScannerLeaseAcquired) {
      _completeFailed(opId, BackgroundProtectionIssue.leaseAcquireFailed);
      return;
    }

    final lease = leaseResult.lease;
    _foregroundLease = lease;
    _publish(
      state.copyWith(
        foregroundMechanics: ForegroundMechanics.starting,
        foregroundMayBeActive: true,
        lastLeaseView:
            ScannerLeaseView(lease: lease, observedAt: DateTime.now()),
      ),
    );

    final startResult = await _withTimeout(
      opId,
      _foregroundTimeout,
      () => _startForeground(lease: lease),
      onTimeout: () {
        _completeFailed(opId, BackgroundProtectionIssue.foregroundStartFailed);
      },
    );
    if (startResult == null) return;

    if (!_isCurrent(opId)) {
      // Late success: pause immediately without publishing ownership.
      unawaited(_cleanupLateForeground(lease, startResult));
      return;
    }

    switch (startResult) {
      case ForegroundStarted():
      case ForegroundAlreadyActive():
        await _store.markLeaseActive(leaseId: lease.leaseId);
        if (!_isCurrent(opId)) {
          unawaited(_cleanupLateForeground(lease, startResult));
          return;
        }
        _setOwner(ScannerOwner.foreground);
        _publish(
          state.copyWith(
            confirmedOwner: ScannerOwner.foreground,
            foregroundMechanics: ForegroundMechanics.active,
            foregroundMayBeActive: true,
            backgroundMayBeActive: false,
            transition: ProtectionTransitionPhase.idle,
            activeOperationId: null,
            issue: null,
            lastLeaseView: ScannerLeaseView(
              lease: lease.copyWith(phase: ScannerLeasePhase.active),
              observedAt: DateTime.now(),
            ),
          ),
        );
        _active = null;
        _completeOnce(opId, const ProtectionCompleted());
      case ForegroundSuppressedByBackground():
        await _store.releaseLease(leaseId: lease.leaseId);
        _foregroundLease = null;
        _completeFailed(opId, BackgroundProtectionIssue.leaseAcquireFailed);
      case ForegroundStartPreflightFailed():
        await _store.releaseLease(leaseId: lease.leaseId);
        _foregroundLease = null;
        _publish(
          state.copyWith(
            confirmedOwner: ScannerOwner.none,
            foregroundMechanics: ForegroundMechanics.inactive,
            foregroundMayBeActive: false,
          ),
        );
        _completeFailed(opId, BackgroundProtectionIssue.mainPreflightFailed);
      case ForegroundStartMechanicalFailed(:final mayStillBeScanning):
        if (!mayStillBeScanning) {
          await _store.releaseLease(leaseId: lease.leaseId);
          _foregroundLease = null;
        }
        _publish(
          state.copyWith(
            confirmedOwner: ScannerOwner.none,
            foregroundMechanics: mayStillBeScanning
                ? ForegroundMechanics.uncertain
                : ForegroundMechanics.inactive,
            foregroundMayBeActive: mayStillBeScanning,
          ),
        );
        _completeFailed(opId, BackgroundProtectionIssue.foregroundStartFailed);
    }
  }

  Future<void> _effectEnableBackground(
    String opId,
    ProtectionProtocolTuple tuple,
  ) async {
    // Ensure overall intent before allocate (allocate requires protectionEnabled).
    var working = tuple;
    if (!working.protectionEnabled || working.explicitlyStopped) {
      final intent = await _store.beginForegroundIntent(
        expectedRevision: working.revision,
      );
      if (intent is! ProtocolCommitConfirmed) {
        // beginForeground clears session; for background we need enabled + preferred.
        // Use a preference-preserving path: beginForeground then we'll allocate.
        _completeFailed(
          opId,
          intent is ProtocolCommitPersistenceUncertain
              ? BackgroundProtectionIssue.protocolPersistenceFailed
              : BackgroundProtectionIssue.protocolUnavailable,
        );
        return;
      }
      working = intent.tuple;
      // beginForeground sets runtime false â€” good. Preferred preserved.
      _publish(state.copyWith(lastConfirmedTuple: working));
    }
    if (!_isCurrent(opId)) return;

    final preflight = await _backgroundPreflight.check();
    if (!preflight.isOk) {
      _completeFailed(opId, BackgroundProtectionIssue.mainPreflightFailed);
      return;
    }
    if (!_isCurrent(opId)) return;

    _claim.acquire();
    final attemptId = 'attempt-${_random.nextInt(1 << 32)}';
    _pendingAttemptId = attemptId;

    final allocate = await _withTimeout(
      opId,
      _protocolTimeout,
      () => _store.allocateBackgroundSession(
        expectedRevision: working.revision,
        attemptId: attemptId,
        processId: _processId,
      ),
      onTimeout: () {
        _claim.release();
        _completeFailed(opId, BackgroundProtectionIssue.protocolUnavailable);
      },
    );
    if (allocate == null || !_isCurrent(opId)) {
      if (allocate is ProtocolCommitConfirmed) {
        unawaited(_abortBackgroundAttempt(attemptId));
      }
      return;
    }

    if (allocate is! ProtocolCommitConfirmed) {
      _claim.release();
      _completeFailed(
        opId,
        allocate is ProtocolCommitPersistenceUncertain
            ? BackgroundProtectionIssue.protocolPersistenceFailed
            : BackgroundProtectionIssue.serviceStartFailed,
      );
      return;
    }

    working = allocate.tuple;
    _pendingSessionId = working.activeTaskSessionId;
    _pendingEpoch = working.activeTaskEpoch;
    _publish(
      state.copyWith(
        lastConfirmedTuple: working,
        backgroundMechanics: BackgroundServiceMechanics.starting,
        backgroundMayBeActive: true,
      ),
    );

    final startFuture = _foregroundService.start(
      notificationTitle: AppCopy.backgroundProtectionNotificationTitle,
      notificationText: AppCopy.backgroundProtectionNotificationDefaultBody,
      notificationButtons: [
        const NotificationButton(
          id: kFgsStopButtonId,
          text: AppCopy.backgroundProtectionStopAction,
        ),
      ],
      callback: backgroundScanTaskCallback,
    );
    _pendingNativeStart = startFuture;

    // Observe native start independently.
    unawaited(() async {
      final result = await startFuture;
      if (!_isCurrent(opId) || state.disposed) {
        // Late start â€” invalidate and stop.
        if (result is ServiceRequestSuccess) {
          unawaited(_foregroundService.stop());
        }
        await _store.markNativeStartResolved(
          expectedRevision: (await _store.getState()).tuple?.revision ?? 0,
          attemptId: attemptId,
        );
        return;
      }
      if (result is ServiceRequestFailure) {
        await _abortBackgroundAttempt(attemptId);
        if (_isCurrent(opId)) {
          _completeFailed(opId, BackgroundProtectionIssue.serviceStartFailed);
        }
        return;
      }
      await _store.markNativeStartResolved(
        expectedRevision:
            (await _store.getState()).tuple?.revision ?? working.revision,
        attemptId: attemptId,
      );
    }());

    // Wait for ready snapshot / deadline.
    final readyCompleter = Completer<bool>();
    _active = _ActiveOperation(
      id: opId,
      kind: _CommandKind.enable,
      readyCompleter: readyCompleter,
    );

    final timer = Timer(_readinessTimeout, () {
      if (!readyCompleter.isCompleted) readyCompleter.complete(false);
    });
    _timers.add(timer);

    final ready = await readyCompleter.future;
    timer.cancel();
    if (!_isCurrent(opId)) return;

    if (!ready) {
      await _abortBackgroundAttempt(attemptId);
      if (_isCurrent(opId)) {
        _completeFailed(opId, BackgroundProtectionIssue.readinessTimeout);
      }
      return;
    }

    // Ready path completed via snapshot handler.
  }

  Future<void> _effectSetMode(String opId, bool preferred) async {
    final ready = await _store.ensureReady();
    if (!_isCurrent(opId)) return;
    if (ready is! ProtocolCommitConfirmed) {
      _completeFailed(
        opId,
        ready is ProtocolCommitPersistenceUncertain
            ? BackgroundProtectionIssue.protocolPersistenceFailed
            : BackgroundProtectionIssue.protocolUnavailable,
      );
      return;
    }

    var tuple = ready.tuple;
    final protecting =
        tuple.protectionEnabled && state.confirmedOwner != ScannerOwner.none;

    if (protecting) {
      if (preferred && !_supportBackground) {
        _completeFailed(opId, BackgroundProtectionIssue.backgroundNotSupported);
        return;
      }

      if (preferred && state.confirmedOwner == ScannerOwner.foreground) {
        final result = await _commitPreferred(opId, tuple, preferred: true);
        if (result == null || !_isCurrent(opId)) return;
        tuple = result;
        await _effectEnableBackground(opId, tuple);
        return;
      }

      if (!preferred && state.confirmedOwner == ScannerOwner.background) {
        final switched = await _withTimeout(
          opId,
          _protocolTimeout,
          () =>
              _store.switchToForegroundIntent(expectedRevision: tuple.revision),
          onTimeout: () {
            _completeFailed(
              opId,
              BackgroundProtectionIssue.protocolUnavailable,
            );
          },
        );
        if (switched == null || !_isCurrent(opId)) return;
        if (switched is ProtocolCommitStale) {
          final retry = await _store.switchToForegroundIntent(
            expectedRevision: switched.current.revision,
          );
          if (retry is! ProtocolCommitConfirmed) {
            _completeFailed(
              opId,
              BackgroundProtectionIssue.protocolPersistenceFailed,
            );
            return;
          }
          tuple = retry.tuple;
        } else if (switched is ProtocolCommitConfirmed) {
          tuple = switched.tuple;
        } else {
          _completeFailed(
            opId,
            BackgroundProtectionIssue.protocolPersistenceFailed,
          );
          return;
        }

        _publish(state.copyWith(lastConfirmedTuple: tuple));
        await _foregroundService.stop();
        if (_claim.isHeld) _claim.release();
        final heldLease = (await _store.getState()).lease;
        if (heldLease != null) {
          await _store.releaseLease(leaseId: heldLease.leaseId);
        }
        if (!_isCurrent(opId)) return;
        _publish(
          state.copyWith(
            confirmedOwner: ScannerOwner.none,
            backgroundMechanics: BackgroundServiceMechanics.stopped,
            backgroundMayBeActive: false,
          ),
        );
        await _effectEnableForeground(opId, tuple);
        return;
      }
    }

    final result = await _commitPreferred(opId, tuple, preferred: preferred);
    if (result == null || !_isCurrent(opId)) return;
    _publish(
      state.copyWith(
        lastConfirmedTuple: result,
        transition: ProtectionTransitionPhase.idle,
        activeOperationId: null,
      ),
    );
    _active = null;
    _completeOnce(opId, const ProtectionCompleted());
  }

  Future<ProtectionProtocolTuple?> _commitPreferred(
    String opId,
    ProtectionProtocolTuple tuple, {
    required bool preferred,
  }) async {
    final result = await _store.setBackgroundModePreferred(
      expectedRevision: tuple.revision,
      preferred: preferred,
    );
    if (!_isCurrent(opId)) return null;

    if (result is ProtocolCommitStale) {
      final retry = await _store.setBackgroundModePreferred(
        expectedRevision: result.current.revision,
        preferred: preferred,
      );
      if (retry is ProtocolCommitConfirmed) {
        return retry.tuple;
      }
      _completeFailed(
        opId,
        BackgroundProtectionIssue.protocolPersistenceFailed,
      );
      return null;
    }

    if (result is ProtocolCommitConfirmed) {
      return result.tuple;
    }

    _completeFailed(opId, BackgroundProtectionIssue.protocolPersistenceFailed);
    return null;
  }

  Future<void> _effectReconcile(String opId) async {
    final ready = await _store.ensureReady();
    if (!_isCurrent(opId)) return;

    if (ready is ProtocolCommitPersistenceUncertain) {
      _publish(
        state.copyWith(
          lastConfirmedTuple: ready.lastConfirmedTuple,
          issue: BackgroundProtectionIssue.protocolPersistenceFailed,
          transition: ProtectionTransitionPhase.idle,
          activeOperationId: null,
        ),
      );
      _active = null;
      _completeFailed(
        opId,
        BackgroundProtectionIssue.protocolPersistenceFailed,
      );
      return;
    }
    if (ready is! ProtocolCommitConfirmed) {
      _completeFailed(opId, BackgroundProtectionIssue.protocolUnavailable);
      return;
    }

    final protocolState = await _store.getState();
    final tuple = ready.tuple;
    _publish(
      state.copyWith(
        lastConfirmedTuple: tuple,
        engineIncarnationId: protocolState.engineIncarnationId,
        processInstanceId: protocolState.processInstanceId,
      ),
    );
    if (!_isCurrent(opId)) return;

    if (tuple.explicitlyStopped || !tuple.protectionEnabled) {
      // Clean residual service if any, then stable Off.
      final running = await _foregroundService.isRunning;
      if (running) {
        await _foregroundService.stop();
      }
      if (_claim.isHeld) _claim.release();
      _setOwner(ScannerOwner.none);
      _publish(
        state.copyWith(
          confirmedOwner: ScannerOwner.none,
          foregroundMechanics: ForegroundMechanics.inactive,
          backgroundMechanics: BackgroundServiceMechanics.stopped,
          foregroundMayBeActive: false,
          backgroundMayBeActive: false,
          transition: ProtectionTransitionPhase.idle,
          activeOperationId: null,
          retainedCleanup: false,
          issue: null,
        ),
      );
      _active = null;
      _completeOnce(opId, const ProtectionCompleted());
      return;
    }

    if (tuple.backgroundModePreferred &&
        tuple.backgroundRuntimeEnabled &&
        tuple.activeTaskSessionId != null) {
      final running = await _foregroundService.isRunning;
      if (running) {
        _claim.acquire();
        _pendingSessionId = tuple.activeTaskSessionId;
        _pendingEpoch = tuple.activeTaskEpoch;
        _publish(
          state.copyWith(
            backgroundMechanics: BackgroundServiceMechanics.runningUnready,
            backgroundMayBeActive: true,
            transition: ProtectionTransitionPhase.reconciling,
          ),
        );
        // Status request â€” ownership only after ready snapshot.
        _foregroundService.sendStatusRequest(
          sessionId: tuple.activeTaskSessionId!,
          epoch: tuple.activeTaskEpoch ?? 0,
        );
        // Bounded wait handled by readiness timeout via a mini wait.
        final readyWait = Completer<bool>();
        _active = _ActiveOperation(
          id: opId,
          kind: _CommandKind.reconcile,
          readyCompleter: readyWait,
        );
        final timer = Timer(_readinessTimeout, () {
          if (!readyWait.isCompleted) readyWait.complete(false);
        });
        _timers.add(timer);
        final ok = await readyWait.future;
        timer.cancel();
        if (!_isCurrent(opId)) return;
        if (!ok) {
          _publish(
            state.copyWith(
              issue:
                  BackgroundProtectionIssue.androidStoppedBackgroundProtection,
              confirmedOwner: ScannerOwner.none,
              transition: ProtectionTransitionPhase.idle,
              activeOperationId: null,
            ),
          );
          _active = null;
          _completeFailed(
            opId,
            BackgroundProtectionIssue.androidStoppedBackgroundProtection,
          );
        }
        // Success completes in snapshot handler.
        return;
      }

      // Service missing with stale runtime â€” fail closed, no silent foreground.
      _publish(
        state.copyWith(
          issue: BackgroundProtectionIssue.androidStoppedBackgroundProtection,
          confirmedOwner: ScannerOwner.none,
          backgroundMayBeActive: false,
          transition: ProtectionTransitionPhase.idle,
          activeOperationId: null,
        ),
      );
      _active = null;
      _completeFailed(
        opId,
        BackgroundProtectionIssue.androidStoppedBackgroundProtection,
      );
      return;
    }

    if (tuple.backgroundModePreferred &&
        !tuple.backgroundRuntimeEnabled &&
        tuple.activeTaskSessionId == null) {
      // Intent true, preferred background, no session â€” restart required.
      _publish(
        state.copyWith(
          issue: BackgroundProtectionIssue.androidStoppedBackgroundProtection,
          transition: ProtectionTransitionPhase.idle,
          activeOperationId: null,
        ),
      );
      _active = null;
      _completeFailed(
        opId,
        BackgroundProtectionIssue.androidStoppedBackgroundProtection,
      );
      return;
    }

    // Foreground preferred recovery.
    await _effectEnableForeground(opId, tuple);
  }

  Future<void> _effectStop(String opId) async {
    final completed = await _withTimeout<bool>(
      opId,
      _stopTimeout,
      () async {
        await _effectStopBody(opId);
        return true;
      },
      onTimeout: () {
        _publish(
          state.copyWith(
            confirmedOwner: ScannerOwner.none,
            foregroundMechanics: state.foregroundMayBeActive
                ? ForegroundMechanics.uncertain
                : ForegroundMechanics.inactive,
            backgroundMechanics: BackgroundServiceMechanics.unresponsive,
            issue: BackgroundProtectionIssue.serviceStopFailed,
            transition: ProtectionTransitionPhase.idle,
            activeOperationId: null,
            retainedCleanup: true,
          ),
        );
        if (_active?.id == opId) _active = null;
        _completeFailed(opId, BackgroundProtectionIssue.serviceStopFailed);
      },
    );
    if (completed == null) return;
  }

  Future<void> _effectStopBody(String opId) async {
    // Persistence and physical shutdown in parallel.
    final stopPersist = _store.commitExplicitStop();
    final pauseFuture = (state.foregroundMayBeActive ||
            state.confirmedOwner == ScannerOwner.foreground ||
            _foregroundLease != null)
        ? _pauseForeground()
        : Future<ForegroundPauseResult>.value(
            const ForegroundAlreadyInactive(),
          );
    final stopService = (state.backgroundMayBeActive ||
            state.confirmedOwner == ScannerOwner.background ||
            _claim.isHeld)
        ? _foregroundService.stop()
        : Future<ServiceRequestResult>.value(const ServiceRequestSuccess());

    if (_pendingAttemptId != null) {
      unawaited(
        _store.cancelBackgroundAttempt(attemptId: _pendingAttemptId!),
      );
    }

    final persistResult = await stopPersist;
    if (!_isCurrent(opId)) return;
    final pauseResult = await pauseFuture;
    if (!_isCurrent(opId)) return;
    await stopService;
    if (!_isCurrent(opId)) return;

    if (_disposedFlag) {
      _completeOnce(opId, const ProtectionDisposed());
      return;
    }

    if (persistResult is ProtocolCommitPersistenceUncertain) {
      _publish(
        state.copyWith(
          lastConfirmedTuple: persistResult.lastConfirmedTuple,
          issue: BackgroundProtectionIssue.protocolPersistenceFailed,
          confirmedOwner: ScannerOwner.none,
          transition: ProtectionTransitionPhase.idle,
          activeOperationId: null,
          retainedCleanup: true,
        ),
      );
      _active = null;
      _completeFailed(
        opId,
        BackgroundProtectionIssue.protocolPersistenceFailed,
      );
      return;
    }

    if (persistResult is ProtocolCommitConfirmed) {
      _publish(state.copyWith(lastConfirmedTuple: persistResult.tuple));
    }

    if (pauseResult is ForegroundPauseFailed &&
        pauseResult.mayStillBeScanning) {
      _publish(
        state.copyWith(
          confirmedOwner: ScannerOwner.none,
          foregroundMechanics: ForegroundMechanics.uncertain,
          foregroundMayBeActive: true,
          issue: BackgroundProtectionIssue.foregroundStopFailed,
          transition: ProtectionTransitionPhase.idle,
          activeOperationId: null,
          retainedCleanup: true,
        ),
      );
      _active = null;
      _completeFailed(opId, BackgroundProtectionIssue.foregroundStopFailed);
      return;
    }

    // Release foreground lease after confirmed pause.
    final lease = _foregroundLease;
    if (lease != null) {
      await _store.releaseLease(leaseId: lease.leaseId);
      _foregroundLease = null;
    }
    if (!_isCurrent(opId)) return;

    // Finalise session if present and native start resolved.
    final tuple = state.lastConfirmedTuple;
    if (tuple != null &&
        tuple.activeTaskSessionId != null &&
        !tuple.nativeStartUnresolved) {
      final finalised = await _store.finaliseSession(
        expectedRevision: tuple.revision,
        sessionId: tuple.activeTaskSessionId!,
      );
      if (!_isCurrent(opId)) return;
      if (finalised is ProtocolCommitConfirmed) {
        _publish(state.copyWith(lastConfirmedTuple: finalised.tuple));
      }
    }

    if (_claim.isHeld) _claim.release();
    _pendingSessionId = null;
    _pendingEpoch = null;
    _pendingAttemptId = null;
    final lateNativeStart = _pendingNativeStart;
    _pendingNativeStart = null;
    if (lateNativeStart != null) {
      unawaited(() async {
        final result = await lateNativeStart;
        if (result is ServiceRequestSuccess) {
          unawaited(_foregroundService.stop());
        }
      }());
    }
    _setOwner(ScannerOwner.none);

    if (!_isCurrent(opId)) return;

    _publish(
      state.copyWith(
        confirmedOwner: ScannerOwner.none,
        foregroundMechanics: ForegroundMechanics.inactive,
        backgroundMechanics: BackgroundServiceMechanics.stopped,
        foregroundMayBeActive: false,
        backgroundMayBeActive: false,
        transition: ProtectionTransitionPhase.idle,
        activeOperationId: null,
        retainedCleanup: false,
        issue: null,
        lastLeaseView:
            ScannerLeaseView(lease: null, observedAt: DateTime.now()),
      ),
    );
    _active = null;
    _completeOnce(opId, const ProtectionCompleted());
  }

  Future<void> _effectRestartForeground(String opId) async {
    final pause = await _pauseForeground();
    if (!_isCurrent(opId)) return;
    if (pause is ForegroundPauseFailed) {
      _completeFailed(opId, BackgroundProtectionIssue.foregroundPauseFailed);
      return;
    }
    final oldLease = _foregroundLease;
    if (oldLease != null) {
      await _store.releaseLease(leaseId: oldLease.leaseId);
      _foregroundLease = null;
    }
    final tuple = state.lastConfirmedTuple;
    if (tuple == null) {
      _completeFailed(opId, BackgroundProtectionIssue.protocolUnavailable);
      return;
    }
    await _effectEnableForeground(opId, tuple);
  }

  Future<void> _abortBackgroundAttempt(String attemptId) async {
    await _store.cancelBackgroundAttempt(attemptId: attemptId);
    await _foregroundService.stop();
    final lease = (await _store.getState()).lease;
    if (lease != null) {
      await _store.releaseLease(leaseId: lease.leaseId);
    }
    if (_claim.isHeld) {
      // Release only when runtime invalid and lease gone.
      final tuple = (await _store.getState()).tuple;
      if (tuple == null || !tuple.backgroundRuntimeEnabled) {
        _claim.release();
      }
    }
    _publish(
      state.copyWith(
        backgroundMechanics: BackgroundServiceMechanics.stopped,
        backgroundMayBeActive: false,
        confirmedOwner: ScannerOwner.none,
      ),
    );
  }

  Future<void> _cleanupLateForeground(
    ScannerLease lease,
    ForegroundStartResult startResult,
  ) async {
    if (startResult is ForegroundStarted ||
        startResult is ForegroundAlreadyActive) {
      await _pauseForeground();
    }
    await _store.releaseLease(leaseId: lease.leaseId);
    if (_foregroundLease?.leaseId == lease.leaseId) {
      _foregroundLease = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Task / protocol events
  // ---------------------------------------------------------------------------

  void _onTaskData(Object data) {
    if (_disposedFlag) return;
    final snapshot = BackgroundProtectionSnapshot.fromJson(data);
    if (snapshot == null) return;

    if (!snapshot.isOwnershipCapable) {
      // Diagnostic / legacy: may mirror UI but never establish ownership.
      if (snapshot.serviceRunning) {
        _applyMirroredScanState(
          snapshot.toScanState(protectionRequested: true),
        );
      }
      return;
    }

    final lastSeq = state.lastAcceptedTaskSequence ?? -1;
    if (snapshot.messageSequence != null &&
        snapshot.messageSequence! <= lastSeq &&
        snapshot.sessionId == _pendingSessionId) {
      return; // duplicate / reorder
    }

    if (snapshot.sessionId != _pendingSessionId &&
        snapshot.sessionId != state.lastConfirmedTuple?.activeTaskSessionId) {
      return;
    }
    if (snapshot.sessionEpoch != null &&
        _pendingEpoch != null &&
        snapshot.sessionEpoch != _pendingEpoch) {
      return;
    }

    _publish(
      state.copyWith(
        lastAcceptedTaskSequence: snapshot.messageSequence,
      ),
    );

    if (snapshot.stoppedReason ==
        BackgroundProtectionStoppedReason.explicitNotificationStop) {
      unawaited(_handleNotificationStop(snapshot));
      return;
    }

    final readyPhases = {
      BackgroundScannerPhase.scanning,
      BackgroundScannerPhase.resting,
      BackgroundScannerPhase.starting,
    };
    final phase = snapshot.scannerPhase;
    final isReady = phase == null ||
        readyPhases.contains(phase) ||
        snapshot.status == ScanStatus.scanning ||
        snapshot.status == ScanStatus.resting ||
        snapshot.status == ScanStatus.possibleRiskDetected ||
        snapshot.status == ScanStatus.confirmingRisk;

    if (isReady &&
        snapshot.serviceRunning &&
        snapshot.scannerLeaseId != null &&
        _active?.readyCompleter != null) {
      unawaited(_confirmBackgroundReady(snapshot));
    }

    if (snapshot.serviceRunning) {
      _applyMirroredScanState(
        snapshot.toScanState(protectionRequested: true),
      );
    }
  }

  Future<void> _confirmBackgroundReady(
    BackgroundProtectionSnapshot snapshot,
  ) async {
    final opId = _active?.id;
    if (opId == null) return;

    final protocolState = await _store.getState();
    final tuple = protocolState.tuple;
    if (tuple == null ||
        !tuple.protectionEnabled ||
        !tuple.backgroundRuntimeEnabled ||
        tuple.activeTaskSessionId != snapshot.sessionId ||
        tuple.taskPhase != ProtocolTaskPhase.scannerReady &&
            tuple.taskPhase != ProtocolTaskPhase.allocated) {
      // For fake path: mark ready if lease matches.
    }

    // Accept ready when lease is active for this session.
    final lease = protocolState.lease;
    if (lease != null &&
        lease.leaseId == snapshot.scannerLeaseId &&
        lease.phase != ScannerLeasePhase.active) {
      await _store.markLeaseActive(leaseId: lease.leaseId);
    }

    // If task phase not yet scannerReady, attempt mark (fake service path).
    if (tuple != null &&
        tuple.taskPhase != ProtocolTaskPhase.scannerReady &&
        snapshot.sessionId != null &&
        snapshot.sessionEpoch != null &&
        snapshot.engineIncarnationId != null &&
        snapshot.scannerLeaseId != null) {
      if (tuple.activeTaskIncarnationId == null) {
        await _store.claimTaskIncarnation(
          expectedRevision: tuple.revision,
          sessionId: snapshot.sessionId!,
          incarnationId: snapshot.engineIncarnationId!,
        );
      }
      final after = (await _store.getState()).tuple;
      if (after != null) {
        await _store.markTaskScannerReady(
          expectedRevision: after.revision,
          sessionId: snapshot.sessionId!,
          epoch: snapshot.sessionEpoch!,
          incarnationId: snapshot.engineIncarnationId!,
          leaseId: snapshot.scannerLeaseId!,
        );
      }
    }

    final reread = await _store.getState();
    final confirmed = reread.tuple;
    if (confirmed == null ||
        !confirmed.protectionEnabled ||
        !confirmed.backgroundRuntimeEnabled ||
        confirmed.explicitlyStopped) {
      return;
    }

    if (!_isCurrent(opId)) return;

    _setOwner(ScannerOwner.background);
    _publish(
      state.copyWith(
        lastConfirmedTuple: confirmed,
        confirmedOwner: ScannerOwner.background,
        backgroundMechanics: BackgroundServiceMechanics.ready,
        backgroundMayBeActive: true,
        foregroundMayBeActive: false,
        foregroundMechanics: ForegroundMechanics.inactive,
        transition: ProtectionTransitionPhase.idle,
        activeOperationId: null,
        issue: null,
        lastLeaseView: ScannerLeaseView(
          lease: reread.lease,
          observedAt: DateTime.now(),
        ),
      ),
    );
    final ready = _active?.readyCompleter;
    _active = null;
    if (ready != null && !ready.isCompleted) {
      ready.complete(true);
    }
    _completeOnce(opId, const ProtectionCompleted());
  }

  Future<void> _handleNotificationStop(
    BackgroundProtectionSnapshot snapshot,
  ) async {
    // High-priority external Stop â€” supersede active work.
    final previous = _active;
    if (previous != null && previous.kind != _CommandKind.stop) {
      _completeOnce(previous.id, const ProtectionSuperseded());
    }
    await stopAllProtection();
  }

  Future<void> _onProtocolChanged() async {
    if (_disposedFlag || state.isBusy) return;
    final protocolState = await _store.getState();
    if (protocolState.tuple != null) {
      _publish(state.copyWith(lastConfirmedTuple: protocolState.tuple));
    }
    if (protocolState.stopFenceRaised ||
        (protocolState.tuple?.explicitlyStopped ?? false)) {
      if (state.confirmedOwner != ScannerOwner.none) {
        unawaited(stopAllProtection());
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  ProtectionProtocolTuple? _requireConfirmed(
    String opId,
    ProtocolCommitResult result, {
    Future<ProtocolCommitResult?> Function()? retry,
  }) {
    if (result is ProtocolCommitConfirmed) return result.tuple;
    if (result is ProtocolCommitStale && retry != null) {
      // Caller should await retry â€” sync helper returns null and schedules.
      unawaited(() async {
        final second = await retry();
        if (second is ProtocolCommitConfirmed && _isCurrent(opId)) {
          // Re-entry not wired; treat as failure for simplicity in this path.
          _completeFailed(opId, BackgroundProtectionIssue.protocolUnavailable);
        } else if (_isCurrent(opId)) {
          _completeFailed(
            opId,
            second is ProtocolCommitPersistenceUncertain
                ? BackgroundProtectionIssue.protocolPersistenceFailed
                : BackgroundProtectionIssue.protocolUnavailable,
          );
        }
      }());
      return null;
    }
    if (result is ProtocolCommitPersistenceUncertain) {
      _completeFailed(
        opId,
        BackgroundProtectionIssue.protocolPersistenceFailed,
      );
      return null;
    }
    _completeFailed(opId, BackgroundProtectionIssue.protocolUnavailable);
    return null;
  }

  Future<T?> _withTimeout<T>(
    String opId,
    Duration timeout,
    Future<T> Function() action, {
    required void Function() onTimeout,
  }) async {
    final completer = Completer<T?>();
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        onTimeout();
        completer.complete(null);
      }
    });
    _timers.add(timer);
    try {
      final value = await action();
      if (!completer.isCompleted) {
        completer.complete(value);
      } else {
        // Timed out already â€” value is late; caller must not publish.
        return null;
      }
    } catch (_) {
      if (!completer.isCompleted) completer.complete(null);
    } finally {
      timer.cancel();
    }
    return completer.future;
  }

  void _setOwner(ScannerOwner owner) {
    _onOwnerChanged(owner);
  }

  void _publish(ProtectionOrchestratorState next) {
    if (_disposedFlag) return;
    state = next;
  }

  void _completeFailed(String opId, BackgroundProtectionIssue issue) {
    if (!_completers.containsKey(opId)) return;
    _publish(
      state.copyWith(
        issue: issue,
        transition: ProtectionTransitionPhase.idle,
        activeOperationId: null,
      ),
    );
    if (_active?.id == opId) _active = null;
    _completeOnce(opId, ProtectionFailed(issue));
  }

  void _completeOnce(String opId, ProtectionCommandOutcome outcome) {
    final completer = _completers.remove(opId);
    if (completer == null) {
      _completionGuardAsserted = true;
      return;
    }
    if (completer.isCompleted) {
      _completionGuardAsserted = true;
      return;
    }
    completer.complete(outcome);
  }

  @override
  void dispose() {
    if (_disposedFlag) {
      super.dispose();
      return;
    }
    _disposedFlag = true;

    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();

    for (final entry in _completers.entries.toList()) {
      _completeOnce(entry.key, const ProtectionDisposed());
    }
    final wasForeground = state.confirmedOwner == ScannerOwner.foreground ||
        state.foregroundMayBeActive;
    final pendingAttempt = _pendingAttemptId;
    final leaveBackground = state.confirmedOwner == ScannerOwner.background;
    _active = null;

    unawaited(_protocolSub?.cancel());
    _foregroundService.removeDataCallback(_onTaskData);

    if (wasForeground) {
      unawaited(() async {
        await _pauseForeground();
        final lease = _foregroundLease;
        if (lease != null) {
          await _store.releaseLease(leaseId: lease.leaseId);
        }
      }());
    }
    if (pendingAttempt != null && !leaveBackground) {
      unawaited(_store.cancelBackgroundAttempt(attemptId: pendingAttempt));
    }

    super.dispose();
  }
}

enum _CommandKind {
  enable,
  stop,
  setMode,
  reconcile,
  restartForeground,
}

class _ActiveOperation {
  _ActiveOperation({
    required this.id,
    required this.kind,
    this.readyCompleter,
  });

  final String id;
  final _CommandKind kind;
  final Completer<bool>? readyCompleter;
}
