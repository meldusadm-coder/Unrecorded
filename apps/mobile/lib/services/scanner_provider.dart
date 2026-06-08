import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_radio/unrecorded_radio.dart';

import '../features/scan/scan_state.dart';
import 'dev_testing_prefs.dart';
import 'protection_prefs.dart';
import 'recent_risk_controller.dart';
import 'risk_notification_service.dart';
import 'scan_lifecycle_coordinator.dart';
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

/// True while the foreground service owns the scan loop (main isolate mirrors only).
final backgroundOwnsScanningProvider = StateProvider<bool>((ref) => false);

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
    onStateChanged: (previous, state) {
      ref.read(widgetSyncTriggerProvider.notifier).state++;
      final notifications = ref.read(riskNotificationServiceProvider);
      final backgroundOwns = ref.read(backgroundOwnsScanningProvider);

      if (!backgroundOwns) {
        unawaited(notifications.syncProtectionStatusNotification(state));
      }

      if (previous.status != ScanStatus.possibleRiskDetected &&
          state.status == ScanStatus.possibleRiskDetected) {
        unawaited(
          ref.read(recentRiskControllerProvider.notifier).recordPossibleRisk(
                riskLevel: state.riskLevel,
                reasons: state.safeReasonKeys,
              ),
        );
      }

      if (!backgroundOwns &&
          previous.status != ScanStatus.possibleRiskDetected &&
          state.status == ScanStatus.possibleRiskDetected) {
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

  ref.listen<ScannerConfig?>(scannerConfigProvider, (previous, next) {
    if (previous == null || next == null || previous == next) return;
    unawaited(controller.onScannerConfigChanged());
  });

  return controller;
});

final widgetSyncTriggerProvider = StateProvider<int>((ref) => 0);

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

class ScanController extends StateNotifier<ScanState> {
  ScanController({
    required ScanLifecycleCoordinator coordinator,
    required DetectionPipeline pipeline,
    required SignalUiMapper mapper,
    void Function(ScanState previous, ScanState next)? onStateChanged,
    Duration startupGraceDuration = const Duration(seconds: 5),
    int requiredElevatedScans = 2,
  })  : _coordinator = coordinator,
        _mapper = mapper,
        _onStateChanged = onStateChanged,
        super(const ScanState()) {
    _coordinator.onStateChanged = _onCoordinatorState;
  }

  final ScanLifecycleCoordinator _coordinator;
  final SignalUiMapper _mapper;
  final void Function(ScanState previous, ScanState next)? _onStateChanged;

  bool _startInFlight = false;
  ProtectionPrefs? _prefs;

  void _onCoordinatorState(ScanState partial, PipelineResult pipelineResult) {
    final (risk, other) =
        _mapper.partition(pipelineResult.snapshot.assessments);

    // `alertDismissed` is UI-only; preserve it only while the same risky
    // device(s) remain — not merely while status stays possibleRiskDetected.
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

  Future<ProtectionPrefs> _ensurePrefs() async {
    _prefs ??= await ProtectionPrefs.load();
    return _prefs!;
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

  Future<void> onScannerConfigChanged() async {
    if (!state.protectionRequested || state.status == ScanStatus.paused) {
      return;
    }
    final wasRequested = state.protectionRequested;
    await _coordinator.pauseProtection();
    if (wasRequested) {
      await startProtection(persist: false);
    }
  }

  bool _backgroundOwnsScanning = false;

  void setBackgroundOwnsScanning(bool value) {
    _backgroundOwnsScanning = value;
  }

  /// Applies state mirrored from the foreground-service task isolate.
  void applyMirroredState(ScanState mirrored) {
    _emit(mirrored);
  }

  Future<void> startProtection({bool persist = true}) async {
    if (_backgroundOwnsScanning) return;

    if (_startInFlight ||
        state.status == ScanStatus.scanning ||
        state.status == ScanStatus.resting ||
        state.status == ScanStatus.possibleRiskDetected ||
        state.status == ScanStatus.starting ||
        state.status == ScanStatus.confirmingRisk) {
      return;
    }

    _startInFlight = true;
    try {
      if (persist) {
        final prefs = await _ensurePrefs();
        await prefs.setProtectionEnabled(true);
      }

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

      final failure = await _coordinator.startProtection();
      if (failure != null) {
        _emit(
          state.copyWith(
            status: _statusForPreflight(failure),
            statusMessage: _messageForPreflight(failure),
            protectionRequested: true,
          ),
        );
        return;
      }

      _emit(
        state.copyWith(
          status: ScanStatus.scanning,
          isDemoMode: _coordinator.isDemoMode,
          clearStatusMessage: true,
        ),
      );
    } finally {
      _startInFlight = false;
    }
  }

  Future<void> pauseProtection({bool persist = true}) async {
    if (persist) {
      final prefs = await _ensurePrefs();
      await prefs.setProtectionEnabled(false);
    }
    await _coordinator.pauseProtection();
    _emit(
      state.copyWith(
        protectionRequested: false,
        status: ScanStatus.paused,
        possibleRiskSignals: const [],
        otherNearbySignals: const [],
        clearStatusMessage: true,
      ),
    );
  }

  ScanStatus _statusForPreflight(ScanPreflightFailure failure) {
    return switch (failure) {
      ScanPreflightFailure.permissionDenied => ScanStatus.permissionDenied,
      ScanPreflightFailure.permissionPermanentlyDenied =>
        ScanStatus.permissionPermanentlyDenied,
      ScanPreflightFailure.bluetoothOff => ScanStatus.bluetoothOff,
      ScanPreflightFailure.bluetoothUnsupported =>
        ScanStatus.bluetoothUnsupported,
    };
  }

  String _messageForPreflight(ScanPreflightFailure failure) {
    return switch (failure) {
      ScanPreflightFailure.permissionDenied => AppCopy.permissionHelper,
      ScanPreflightFailure.permissionPermanentlyDenied =>
        AppCopy.permissionPermanentlyDeniedHelper,
      ScanPreflightFailure.bluetoothUnsupported =>
        AppCopy.bluetoothUnsupportedMessage,
      ScanPreflightFailure.bluetoothOff => AppCopy.bluetoothOffMessage,
    };
  }
}
