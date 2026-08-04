import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_radio/unrecorded_radio.dart';

import '../features/scan/scan_state.dart';
import 'dev_testing_prefs.dart';
import 'protection_protocol_models.dart';
import 'protection_state.dart';
import 'recent_risk_controller.dart';
import 'risk_notification_service.dart';
import 'scan_lifecycle_coordinator.dart';
import 'scan_preflight_mapping.dart';
import 'scan_runtime.dart';
import 'scanner_config.dart';
import 'signal_ui_mapper.dart';

final scannerConfigProvider = StateProvider<ScannerConfig?>((ref) => null);

final scannerConfigInitProvider = FutureProvider<void>((ref) async {
  final runtime = ref.read(scanRuntimeProvider);
  final config = await resolveScannerConfig(
    isEmulator: runtime.isEmulator,
  );
  ref.read(scannerConfigProvider.notifier).state = config;
});

final scanRuntimeProvider = Provider<ScanRuntime>((ref) => const ScanRuntime());

/// Mutable gate shared by orchestrator and [ScanController].
final backgroundOwnershipClaimProvider =
    Provider<BackgroundOwnershipClaim>((ref) {
  return BackgroundOwnershipClaim();
});

/// Confirmed scanner owner from the orchestrator (none/foreground/background).
final scannerOwnerProvider =
    StateProvider<ScannerOwner>((ref) => ScannerOwner.none);

/// True while background owns scanning (compatibility for notification sync).
final backgroundOwnsScanningProvider = Provider<bool>((ref) {
  return ref.watch(scannerOwnerProvider) == ScannerOwner.background;
});

RadioScanner _scannerForConfig(ScannerConfig config) {
  if (config.mode == ScannerMode.demo) {
    return FakeRadioScanner(scenario: config.scenario);
  }
  if (Platform.isAndroid) return BleRadioScanner();
  return FakeRadioScanner(scenario: config.scenario);
}

final radioScannerProvider = Provider<RadioScanner>((ref) {
  final config = ref.watch(scannerConfigProvider);
  if (config == null) {
    return FakeRadioScanner(scenario: FakeDemoScenario.low);
  }
  return _scannerForConfig(config);
});

final detectionPipelineProvider = Provider<DetectionPipeline>((ref) {
  return DetectionPipeline();
});

final signalUiMapperProvider = Provider<SignalUiMapper>((ref) {
  return const SignalUiMapper();
});

/// UI-facing scan coordinator (lifecycle delegated to [ScanLifecycleCoordinator]).
final scanControllerProvider =
    StateNotifierProvider<ScanController, ScanState>((ref) {
  final pipeline = ref.watch(detectionPipelineProvider);
  var latestScanState = const ScanState();
  final claim = ref.watch(backgroundOwnershipClaimProvider);
  final controller = ScanController(
    coordinator: ScanLifecycleCoordinator(
      scannerFactory: () => ref.read(radioScannerProvider),
      runtime: ref.read(scanRuntimeProvider),
      scannerModeFactory: () =>
          ref.read(scannerConfigProvider)?.mode ?? ScannerMode.demo,
      pipeline: pipeline,
    ),
    pipeline: pipeline,
    mapper: ref.read(signalUiMapperProvider),
    backgroundClaim: claim,
    onStateChanged: (previous, state) {
      latestScanState = state;
      final notifications = ref.read(riskNotificationServiceProvider);
      final backgroundOwns =
          ref.read(scannerOwnerProvider) == ScannerOwner.background;

      if (!backgroundOwns) {
        unawaited(
          notifications.syncProtectionStatusNotification(
            state,
            recentRiskVisible: _recentRiskVisibleForNotification(ref, state),
          ),
        );
      }

      if (!backgroundOwns &&
          previous.status != ScanStatus.possibleRiskDetected &&
          state.status == ScanStatus.possibleRiskDetected) {
        unawaited(
          ref.read(recentRiskControllerProvider.notifier).recordPossibleRisk(
                riskLevel: state.riskLevel,
                reasons: state.safeReasonKeys,
              ),
        );
        unawaited(
          notifications.showRiskAlertIfEnabled(riskLevel: state.riskLevel),
        );
      }

      final riskCleared = previous.hasElevatedRisk && !state.hasElevatedRisk;
      final leftAlert = previous.status == ScanStatus.possibleRiskDetected &&
          state.status != ScanStatus.possibleRiskDetected;
      final blockedOrPaused = state.isBlocked ||
          state.status == ScanStatus.paused ||
          !state.protectionRequested;

      if (riskCleared || leftAlert || blockedOrPaused) {
        unawaited(notifications.cancelRiskAlert());
      }
    },
  );

  ref.listen<ScannerOwner>(scannerOwnerProvider, (previous, next) {
    final notifications = ref.read(riskNotificationServiceProvider);
    if (previous == ScannerOwner.background &&
        next != ScannerOwner.background) {
      unawaited(
        notifications.syncProtectionStatusNotification(
          latestScanState,
          recentRiskVisible:
              _recentRiskVisibleForNotification(ref, latestScanState),
        ),
      );
    } else if (previous != ScannerOwner.background &&
        next == ScannerOwner.background) {
      unawaited(notifications.cancelProtectionStatusNotification());
    }
  });

  ref.listen(recentRiskControllerProvider, (_, __) {
    if (ref.read(scannerOwnerProvider) == ScannerOwner.background) return;
    unawaited(
      ref
          .read(riskNotificationServiceProvider)
          .syncProtectionStatusNotification(
            latestScanState,
            recentRiskVisible:
                _recentRiskVisibleForNotification(ref, latestScanState),
          ),
    );
  });

  ref.listen<ScannerConfig?>(scannerConfigProvider, (previous, next) {
    if (previous == null || next == null || previous == next) return;
    // Configuration restart is owned by ProtectionOrchestrator.
  });

  return controller;
});

bool _recentRiskVisibleForNotification(Ref ref, ScanState state) {
  final recentState = ref.read(recentRiskControllerProvider);
  final now = ref.read(clockProvider)();
  return isRecentRiskReminderVisible(
    event: recentState.event,
    window: recentState.window,
    hasLiveAlert: state.status == ScanStatus.possibleRiskDetected,
    now: now,
  );
}

final scannerConfigControllerProvider =
    Provider<ScannerConfigController>((ref) {
  return ScannerConfigController(ref);
});

class ScannerConfigController {
  ScannerConfigController(this._ref);

  final Ref _ref;

  Future<void> setMode(ScannerMode mode) async {
    if (kReleaseMode) return;
    final prefs = await DevTestingPrefs.load();
    await prefs.setScannerMode(mode);
    final current = _ref.read(scannerConfigProvider);
    final next = (current ??
            const ScannerConfig(
              mode: ScannerMode.demo,
              scenario: FakeDemoScenario.high,
            ))
        .copyWith(mode: mode);
    _ref.read(scannerConfigProvider.notifier).state = next;
  }

  Future<void> setScenario(FakeDemoScenario scenario) async {
    if (kReleaseMode) return;
    final prefs = await DevTestingPrefs.load();
    await prefs.setDemoScenario(scenario);
    final current = _ref.read(scannerConfigProvider);
    final next = (current ??
            const ScannerConfig(
              mode: ScannerMode.demo,
              scenario: FakeDemoScenario.high,
            ))
        .copyWith(scenario: scenario);
    _ref.read(scannerConfigProvider.notifier).state = next;
  }

  Future<void> clearOverrides() async {
    if (kReleaseMode) return;
    final prefs = await DevTestingPrefs.load();
    await prefs.clearAll();
    final runtime = _ref.read(scanRuntimeProvider);
    final config = await resolveScannerConfig(
      isEmulator: runtime.isEmulator,
    );
    _ref.read(scannerConfigProvider.notifier).state = config;
  }
}

/// Mechanics-only scan controller. Does not write protection preferences.
class ScanController extends StateNotifier<ScanState> {
  ScanController({
    required ScanLifecycleCoordinator coordinator,
    required DetectionPipeline pipeline,
    required SignalUiMapper mapper,
    required BackgroundOwnershipClaim backgroundClaim,
    void Function(ScanState previous, ScanState next)? onStateChanged,
  })  : _coordinator = coordinator,
        _mapper = mapper,
        _backgroundClaim = backgroundClaim,
        _onStateChanged = onStateChanged,
        super(const ScanState()) {
    _coordinator.onStateChanged = _onCoordinatorState;
  }

  final ScanLifecycleCoordinator _coordinator;
  final SignalUiMapper _mapper;
  final BackgroundOwnershipClaim _backgroundClaim;
  final void Function(ScanState previous, ScanState next)? _onStateChanged;

  bool _startInFlight = false;

  void _onCoordinatorState(ScanState partial, PipelineResult pipelineResult) {
    final (risk, other) =
        _mapper.partition(pipelineResult.snapshot.assessments);

    final newRiskKeys = _contributingRiskStableKeys(
      pipelineResult.snapshot.assessments,
    );
    final stillSameAlert = state.status == ScanStatus.possibleRiskDetected &&
        partial.status == ScanStatus.possibleRiskDetected;
    final sameRiskEvidence = stillSameAlert &&
        state.alertDismissed &&
        _sameRiskKeySet(state.dismissedRiskStableKeys, newRiskKeys);
    final alertDismissed = sameRiskEvidence;
    final dismissedRiskStableKeys =
        sameRiskEvidence ? state.dismissedRiskStableKeys : const <String>[];

    final safeReasonKeys = partial.status == ScanStatus.possibleRiskDetected
        ? recentRiskReasonsForAssessments(
            pipelineResult.snapshot.assessments,
          )
        : const <RecentRiskReason>[];

    _emit(
      partial.copyWith(
        possibleRiskSignals: risk,
        otherNearbySignals: other,
        alertDismissed: alertDismissed,
        dismissedRiskStableKeys: dismissedRiskStableKeys,
        safeReasonKeys: safeReasonKeys,
      ),
    );
  }

  void _emit(ScanState newState) {
    final previous = state;
    state = newState;
    _onStateChanged?.call(previous, newState);
  }

  void simulateHighRiskAlert() {
    _coordinator.simulateHighRiskBatch(FakeRadioScanner.highRiskBatch());
    if (state.status == ScanStatus.possibleRiskDetected) {
      _emit(
        state.copyWith(
          alertDismissed: false,
          dismissedRiskStableKeys: const [],
        ),
      );
    }
  }

  void dismissRiskAlert() {
    if (state.status != ScanStatus.possibleRiskDetected) return;
    final keys = state.possibleRiskSignals.map((s) => s.stableKey).toList()
      ..sort();
    _emit(
      state.copyWith(
        alertDismissed: true,
        dismissedRiskStableKeys: keys,
      ),
    );
  }

  static Set<String> _contributingRiskStableKeys(
    List<DetectionAssessment> assessments,
  ) {
    return {
      for (final a in assessments)
        if (a.contributesToRisk) a.signal.stableKey,
    };
  }

  static bool _sameRiskKeySet(List<String> dismissed, Set<String> current) {
    if (dismissed.length != current.length) return false;
    final sortedCurrent = current.toList()..sort();
    for (var i = 0; i < dismissed.length; i++) {
      if (dismissed[i] != sortedCurrent[i]) return false;
    }
    return true;
  }

  /// Applies state mirrored from the foreground-service task isolate.
  void applyMirroredState(ScanState mirrored) {
    _emit(mirrored);
  }

  /// Mechanics-only start. [lease] is required for orchestrator-driven starts.
  Future<ForegroundStartResult> startProtection({
    ScannerLease? lease,
  }) async {
    if (_backgroundClaim.isHeld) {
      return const ForegroundSuppressedByBackground();
    }

    if (_startInFlight ||
        state.status == ScanStatus.scanning ||
        state.status == ScanStatus.resting ||
        state.status == ScanStatus.possibleRiskDetected ||
        state.status == ScanStatus.starting ||
        state.status == ScanStatus.confirmingRisk) {
      return const ForegroundAlreadyActive();
    }

    _startInFlight = true;
    try {
      _emit(
        state.copyWith(
          protectionRequested: true,
          status: ScanStatus.starting,
          statusMessage: AppCopy.permissionHelper,
          possibleRiskSignals: const [],
          otherNearbySignals: const [],
          reasons: const [],
          riskLevel: RiskLevel.low,
          score: 0,
          alertDismissed: false,
          dismissedRiskStableKeys: const [],
          clearStatusMessage: false,
        ),
      );

      final outcome = await _coordinator.startProtection();
      if (outcome.preflight != null) {
        _emit(
          state.copyWith(
            status: scanStatusForPreflightFailure(outcome.preflight!),
            statusMessage: preflightMessageFor(outcome.preflight!),
            protectionRequested: true,
          ),
        );
        return ForegroundStartPreflightFailed(outcome.preflight!);
      }

      switch (outcome.start) {
        case RadioStarted():
          _emit(
            state.copyWith(
              status: ScanStatus.scanning,
              isDemoMode: _coordinator.isDemoMode,
              clearStatusMessage: true,
            ),
          );
          return const ForegroundStarted();
        case null:
          _emit(
            state.copyWith(
              status: ScanStatus.scanning,
              isDemoMode: _coordinator.isDemoMode,
              clearStatusMessage: true,
            ),
          );
          return const ForegroundAlreadyActive();
        case RadioStartCancelledAndStopped():
          _emit(
            state.copyWith(
              status: ScanStatus.paused,
              protectionRequested: true,
            ),
          );
          return const ForegroundStartMechanicalFailed(
            mayStillBeScanning: false,
          );
        case RadioStartFailed(:final mayStillBeScanning):
          _emit(
            state.copyWith(
              status: ScanStatus.error,
              statusMessage: AppCopy.scanErrorMessage,
              protectionRequested: true,
            ),
          );
          return ForegroundStartMechanicalFailed(
            mayStillBeScanning: mayStillBeScanning,
          );
      }
    } finally {
      _startInFlight = false;
    }
  }

  /// Mechanics-only pause. Does not clear durable protection intent.
  Future<ForegroundPauseResult> pauseProtection() async {
    if (state.status == ScanStatus.paused || state.status == ScanStatus.idle) {
      return const ForegroundAlreadyInactive();
    }

    final stop = await _coordinator.pauseProtection();
    _emit(
      state.copyWith(
        protectionRequested: false,
        status: ScanStatus.paused,
        possibleRiskSignals: const [],
        otherNearbySignals: const [],
        clearStatusMessage: true,
      ),
    );

    if (stop is RadioStopFailed) {
      return ForegroundPauseFailed(
        mayStillBeScanning: stop.mayStillBeScanning,
      );
    }
    return const ForegroundPaused();
  }
}
