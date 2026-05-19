import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_radio/unrecorded_radio.dart';

import '../features/scan/scan_state.dart';
import 'protection_prefs.dart';
import 'scan_runtime.dart';

/// Provides the active [RadioScanner] implementation.
final scannerModeProvider = StateProvider<ScannerMode>((ref) {
  final demoFlag = const bool.fromEnvironment('UNRECORDED_DEMO_MODE');
  return demoFlag ? ScannerMode.demo : ScannerMode.auto;
});

final scanRuntimeProvider = Provider<ScanRuntime>((ref) => const ScanRuntime());

final radioScannerProvider = Provider<RadioScanner>((ref) {
  final mode = ref.watch(scannerModeProvider);
  if (mode == ScannerMode.demo) return FakeRadioScanner();
  if (Platform.isAndroid) return BleRadioScanner();
  return FakeRadioScanner();
});

final riskScoringEngineProvider = Provider<RiskScoringEngine>((ref) {
  return RiskScoringEngine();
});

/// Manages continuous protection / scan lifecycle and scoring.
final scanControllerProvider =
    StateNotifierProvider<ScanController, ScanState>((ref) {
  final controller = ScanController(
    scanner: ref.watch(radioScannerProvider),
    runtime: ref.watch(scanRuntimeProvider),
    scannerMode: ref.watch(scannerModeProvider),
    scoringEngine: ref.watch(riskScoringEngineProvider),
    onStateChanged: (state) {
      ref.read(widgetSyncTriggerProvider.notifier).state++;
    },
  );

  return controller;
});

/// Bumped when scan state changes so widget sync can listen.
final widgetSyncTriggerProvider = StateProvider<int>((ref) => 0);

class ScanController extends StateNotifier<ScanState> {
  ScanController({
    required RadioScanner scanner,
    required ScanRuntime runtime,
    required ScannerMode scannerMode,
    required RiskScoringEngine scoringEngine,
    void Function(ScanState state)? onStateChanged,
  })  : _scanner = scanner,
        _runtime = runtime,
        _scannerMode = scannerMode,
        _scoringEngine = scoringEngine,
        _onStateChanged = onStateChanged,
        super(const ScanState());

  final RadioScanner _scanner;
  final RiskScoringEngine _scoringEngine;
  final ScanRuntime _runtime;
  final ScannerMode _scannerMode;
  final void Function(ScanState state)? _onStateChanged;

  StreamSubscription<List<RadioScanResult>>? _subscription;
  bool _startInFlight = false;
  bool _restartInFlight = false;
  ProtectionPrefs? _prefs;

  void _emit(ScanState newState) {
    state = newState;
    _onStateChanged?.call(newState);
  }

  Future<ProtectionPrefs> _ensurePrefs() async {
    _prefs ??= await ProtectionPrefs.load();
    return _prefs!;
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

    final stream = _scanner.scan();
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
      await _scanner.stop();
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
    await _scanner.stop();

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
    unawaited(_scanner.stop());
    super.dispose();
  }
}
