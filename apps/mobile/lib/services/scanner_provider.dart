import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_radio/unrecorded_radio.dart';

import '../features/scan/scan_state.dart';
import 'scan_runtime.dart';

/// Provides the active [RadioScanner] implementation.
///
/// Defaults to [FakeRadioScanner] so the app works immediately in
/// emulators and on devices without BLE access.
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

/// Manages the scan lifecycle and scoring.
final scanControllerProvider =
    StateNotifierProvider<ScanController, ScanState>((ref) {
  return ScanController(
    scanner: ref.watch(radioScannerProvider),
    runtime: ref.watch(scanRuntimeProvider),
    scannerMode: ref.watch(scannerModeProvider),
    scoringEngine: ref.watch(riskScoringEngineProvider),
  );
});

class ScanController extends StateNotifier<ScanState> {
  final RadioScanner _scanner;
  final RiskScoringEngine _scoringEngine;
  final ScanRuntime _runtime;
  final ScannerMode _scannerMode;
  StreamSubscription<List<RadioScanResult>>? _subscription;

  ScanController({
    required RadioScanner scanner,
    required ScanRuntime runtime,
    required ScannerMode scannerMode,
    required RiskScoringEngine scoringEngine,
  })  : _scanner = scanner,
        _runtime = runtime,
        _scannerMode = scannerMode,
        _scoringEngine = scoringEngine,
        super(const ScanState());

  Future<void> startScan() async {
    if (state.status == ScanStatus.scanning) return;

    if (_scannerMode == ScannerMode.auto && _runtime.isAndroid) {
      state = state.copyWith(
        status: ScanStatus.requestingPermission,
        statusMessage:
            'Scanning uses Bluetooth permissions on-device to detect nearby signals.',
      );

      final preflight = await _runtime.ensureAndroidReady();
      if (!preflight.isOk) {
        switch (preflight.failure!) {
          case ScanPreflightFailure.permissionDenied:
            state = state.copyWith(
              status: ScanStatus.permissionDenied,
              statusMessage:
                  'Bluetooth permission is needed to scan nearby devices. Unrecorded never proves recording.',
            );
            return;
          case ScanPreflightFailure.bluetoothUnsupported:
            state = state.copyWith(
              status: ScanStatus.bluetoothUnsupported,
              statusMessage:
                  'Bluetooth scanning is not supported on this device. You can use demo mode for a preview.',
            );
            return;
          case ScanPreflightFailure.bluetoothOff:
            state = state.copyWith(
              status: ScanStatus.bluetoothOff,
              statusMessage:
                  'Bluetooth appears to be off. Turn it on and try again.',
            );
            return;
        }
      }
    }

    state = state.copyWith(status: ScanStatus.scanning, statusMessage: null);

    final stream = _scanner.scan();
    _subscription = stream.listen(
      _onResults,
      onError: (_) {
        state = state.copyWith(
          status: ScanStatus.error,
          statusMessage: 'Scan failed. Please try again.',
        );
      },
      onDone: () {
        if (state.status == ScanStatus.scanning) {
          state = state.copyWith(
            status: ScanStatus.timedOut,
            statusMessage: 'Scan paused after a timeout. Start again to rescan.',
          );
        }
      },
    );
  }

  void stopScan() {
    _subscription?.cancel();
    _subscription = null;
    _scanner.stop();
    state = state.copyWith(status: ScanStatus.idle);
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

    state = state.copyWith(
      status: ScanStatus.scanning,
      signals: signals,
      riskLevel: result.level,
      score: result.totalScore,
      reasons: result.reasons,
    );
  }

  @override
  void dispose() {
    stopScan();
    super.dispose();
  }
}
