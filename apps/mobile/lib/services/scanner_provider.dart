import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_radio/unrecorded_radio.dart';

import '../features/scan/scan_state.dart';

/// Provides the active [RadioScanner] implementation.
///
/// Defaults to [FakeRadioScanner] so the app works immediately in
/// emulators and on devices without BLE access.
final radioScannerProvider = Provider<RadioScanner>((ref) {
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
    scoringEngine: ref.watch(riskScoringEngineProvider),
  );
});

class ScanController extends StateNotifier<ScanState> {
  final RadioScanner _scanner;
  final RiskScoringEngine _scoringEngine;
  StreamSubscription<List<RadioScanResult>>? _subscription;

  ScanController({
    required RadioScanner scanner,
    required RiskScoringEngine scoringEngine,
  })  : _scanner = scanner,
        _scoringEngine = scoringEngine,
        super(const ScanState());

  void startScan() {
    if (state.status == ScanStatus.scanning) return;

    state = state.copyWith(status: ScanStatus.scanning);

    final stream = _scanner.scan();
    _subscription = stream.listen(
      _onResults,
      onError: (_) {
        state = state.copyWith(status: ScanStatus.error);
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
