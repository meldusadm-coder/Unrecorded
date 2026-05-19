import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_radio/unrecorded_radio.dart';

import '../features/scan/scan_state.dart';
import 'dev_testing_prefs.dart';
import 'protection_prefs.dart';
import 'scan_runtime.dart';
import 'scanner_config.dart';

/// Resolved scanner configuration (null until [scannerConfigInitProvider] completes).
final scannerConfigProvider = StateProvider<ScannerConfig?>((ref) => null);

final scannerConfigInitProvider = FutureProvider<void>((ref) async {
  final runtime = ref.read(scanRuntimeProvider);
  final config = await resolveScannerConfig(
    isEmulator: runtime.isEmulator,
  );
  ref.read(scannerConfigProvider.notifier).state = config;
});

final scanRuntimeProvider = Provider<ScanRuntime>((ref) => const ScanRuntime());

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
    return FakeRadioScanner(scenario: FakeDemoScenario.high);
  }
  return _scannerForConfig(config);
});

final riskScoringEngineProvider = Provider<RiskScoringEngine>((ref) {
  return RiskScoringEngine();
});

/// Manages continuous protection / scan lifecycle and scoring.
final scanControllerProvider =
    StateNotifierProvider<ScanController, ScanState>((ref) {
  final controller = ScanController(
    scannerFactory: () => ref.read(radioScannerProvider),
    runtime: ref.read(scanRuntimeProvider),
    scannerModeFactory: () =>
        ref.read(scannerConfigProvider)?.mode ?? ScannerMode.demo,
    scoringEngine: ref.watch(riskScoringEngineProvider),
    onStateChanged: (state) {
      ref.read(widgetSyncTriggerProvider.notifier).state++;
    },
  );

  ref.listen<ScannerConfig?>(scannerConfigProvider, (previous, next) {
    if (previous == null || next == null || previous == next) return;
    unawaited(controller.onScannerConfigChanged());
  });

  return controller;
});

/// Bumped when scan state changes so widget sync can listen.
final widgetSyncTriggerProvider = StateProvider<int>((ref) => 0);

/// Debug-only: update scanner mode/scenario and restart scan if needed.
final scannerConfigControllerProvider = Provider<ScannerConfigController>((ref) {
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
    final next = (current ?? const ScannerConfig(
      mode: ScannerMode.demo,
      scenario: FakeDemoScenario.high,
    )).copyWith(mode: mode);
    _ref.read(scannerConfigProvider.notifier).state = next;
  }

  Future<void> setScenario(FakeDemoScenario scenario) async {
    if (kReleaseMode) return;
    final prefs = await DevTestingPrefs.load();
    await prefs.setDemoScenario(scenario);
    final current = _ref.read(scannerConfigProvider);
    final next = (current ?? const ScannerConfig(
      mode: ScannerMode.demo,
      scenario: FakeDemoScenario.high,
    )).copyWith(scenario: scenario);
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
    required RadioScanner Function() scannerFactory,
    required ScanRuntime runtime,
    required ScannerMode Function() scannerModeFactory,
    required RiskScoringEngine scoringEngine,
    void Function(ScanState state)? onStateChanged,
  })  : _scannerFactory = scannerFactory,
        _runtime = runtime,
        _scannerModeFactory = scannerModeFactory,
        _scoringEngine = scoringEngine,
        _onStateChanged = onStateChanged,
        super(const ScanState());

  final RadioScanner Function() _scannerFactory;
  final RiskScoringEngine _scoringEngine;
  final ScanRuntime _runtime;
  final ScannerMode Function() _scannerModeFactory;
  final void Function(ScanState state)? _onStateChanged;

  StreamSubscription<List<RadioScanResult>>? _subscription;
  RadioScanner? _activeScanner;
  bool _startInFlight = false;
  bool _restartInFlight = false;
  ProtectionPrefs? _prefs;

  ScannerMode get _scannerMode => _scannerModeFactory();

  void _emit(ScanState newState) {
    state = newState;
    _onStateChanged?.call(newState);
  }

  Future<ProtectionPrefs> _ensurePrefs() async {
    _prefs ??= await ProtectionPrefs.load();
    return _prefs!;
  }

  /// Injects a high-risk batch for debug UAT (no BLE required).
  void simulateHighRiskAlert() {
    _onResults(FakeRadioScanner.highRiskBatch());
  }

  /// Restarts the scan stream after scanner config changes.
  Future<void> onScannerConfigChanged() async {
    if (!state.protectionEnabled ||
        state.status == ScanStatus.paused ||
        state.status == ScanStatus.idle) {
      return;
    }
    await _subscription?.cancel();
    _subscription = null;
    await _activeScanner?.stop();
    _activeScanner = null;
    await _beginScanStream();
  }

  /// Starts continuous protection scanning.
  Future<void> startProtection({bool persist = true}) async {
    if (_startInFlight ||
        state.status == ScanStatus.scanning ||
        state.status == ScanStatus.possibleRiskDetected ||
        state.status == ScanStatus.starting) {
      return;
    }

    _startInFlight = true;

    await _subscription?.cancel();
    _subscription = null;

    try {
      if (persist) {
        final prefs = await _ensurePrefs();
        await prefs.setProtectionEnabled(true);
      }

      _emit(
        state.copyWith(
          protectionEnabled: true,
          status: ScanStatus.starting,
          statusMessage: AppCopy.permissionHelper,
          clearStatusMessage: false,
        ),
      );

      if (_scannerMode == ScannerMode.auto && _runtime.isAndroid) {
        final preflight = await _runtime.ensureAndroidReady();
        if (!preflight.isOk) {
          _emit(
            state.copyWith(
              status: ScanStatus.permissionRequired,
              statusMessage: _messageForPreflight(preflight.failure!),
            ),
          );
          return;
        }
      }

      await _beginScanStream();
    } finally {
      _startInFlight = false;
    }
  }

  String _messageForPreflight(ScanPreflightFailure failure) {
    switch (failure) {
      case ScanPreflightFailure.permissionDenied:
        return AppCopy.permissionHelper;
      case ScanPreflightFailure.bluetoothUnsupported:
        return AppCopy.bluetoothUnsupportedMessage;
      case ScanPreflightFailure.bluetoothOff:
        return AppCopy.bluetoothOffMessage;
    }
  }

  Future<void> _beginScanStream() async {
    _emit(
      state.copyWith(
        status: ScanStatus.scanning,
        clearStatusMessage: true,
      ),
    );

    await _activeScanner?.stop();
    _activeScanner = _scannerFactory();
    final stream = _activeScanner!.scan();
    _subscription = stream.listen(
      _onResults,
      onError: (_) {
        if (!state.protectionEnabled) return;
        _emit(
          state.copyWith(
            status: ScanStatus.error,
            statusMessage: 'Scan failed. Please try again.',
          ),
        );
      },
      onDone: () {
        if (state.protectionEnabled &&
            state.status != ScanStatus.paused &&
            state.status != ScanStatus.idle &&
            state.status != ScanStatus.permissionRequired) {
          unawaited(_restartScan());
        }
      },
    );
  }

  Future<void> _restartScan() async {
    if (_restartInFlight || !state.protectionEnabled) return;
    _restartInFlight = true;
    try {
      await _subscription?.cancel();
      _subscription = null;
      await _activeScanner?.stop();
      _activeScanner = null;
      if (!state.protectionEnabled) return;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!state.protectionEnabled) return;
      await _beginScanStream();
    } finally {
      _restartInFlight = false;
    }
  }

  /// Pauses protection scanning.
  Future<void> pauseProtection({bool persist = true}) async {
    if (persist) {
      final prefs = await _ensurePrefs();
      await prefs.setProtectionEnabled(false);
    }

    await _subscription?.cancel();
    _subscription = null;
    await _activeScanner?.stop();
    _activeScanner = null;

    _emit(
      state.copyWith(
        protectionEnabled: false,
        status: ScanStatus.paused,
        clearStatusMessage: true,
      ),
    );
  }

  void _onResults(List<RadioScanResult> results) {
    final now = DateTime.now();
    final signals = results
        .map(
          (r) => DetectedSignal(
            id: r.id,
            displayName: r.name,
            rssi: r.rssi,
            serviceIds: r.serviceUuids,
            seenAt: r.observedAt,
            isConnectable: r.isConnectable,
          ),
        )
        .toList();

    final snapshot = ScanSnapshot(signals: signals, capturedAt: now);
    final result = _scoringEngine.evaluate(snapshot);

    final nextStatus = (result.level == RiskLevel.medium ||
            result.level == RiskLevel.high)
        ? ScanStatus.possibleRiskDetected
        : ScanStatus.scanning;

    _emit(
      state.copyWith(
        status: nextStatus,
        signals: signals,
        riskLevel: result.level,
        score: result.totalScore,
        reasons: result.reasons,
        lastCheckedAt: now,
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_activeScanner?.stop());
    super.dispose();
  }
}
