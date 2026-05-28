import 'dart:async';
import 'dart:math';

import 'fake_demo_scenario.dart';
import 'radio_scan_result.dart';
import 'radio_scanner.dart';

/// A fake scanner that emits realistic sample data.
///
/// Use this when BLE hardware is unavailable (emulator, tests, demo mode).
class FakeRadioScanner implements RadioScanner {
  FakeRadioScanner({this.scenario = FakeDemoScenario.random});

  final FakeDemoScenario scenario;

  StreamController<List<RadioScanResult>>? _controller;
  Timer? _timer;
  final _random = Random();

  @override
  bool get isScanning => _controller != null && !_controller!.isClosed;

  @override
  Stream<List<RadioScanResult>> scan() {
    _controller = StreamController<List<RadioScanResult>>(
      onCancel: () => stop(),
    );
    _startEmitting();
    return _controller!.stream;
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _controller?.close();
    _controller = null;
  }

  void _startEmitting() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_controller == null || _controller!.isClosed) return;
      _controller!.add(_generateBatch());
    });

    if (_controller != null && !_controller!.isClosed) {
      _controller!.add(_generateBatch());
    }
  }

  List<RadioScanResult> _generateBatch() {
    final now = DateTime.now();

    switch (scenario) {
      case FakeDemoScenario.low:
        return _benignBatch(now);
      case FakeDemoScenario.medium:
        return _mediumRiskBatch(now);
      case FakeDemoScenario.high:
        return highRiskBatch(observedAt: now);
      case FakeDemoScenario.random:
        return _randomBatch(now);
    }
  }

  List<RadioScanResult> _randomBatch(DateTime now) {
    final results = _benignBatch(now);

    if (_random.nextInt(3) == 0) {
      results.add(_suspiciousDevice(now));
    }

    if (_random.nextBool()) {
      results.add(
        RadioScanResult(
          id: 'fake:11:22:33:04',
          rssi: -80 + _random.nextInt(15),
          observedAt: now,
        ),
      );
    }

    return results;
  }

  List<RadioScanResult> _benignBatch(DateTime now) {
    return [
      RadioScanResult(
        id: 'fake:aa:bb:cc:01',
        name: 'JBL Flip 6',
        rssi: -65 + _random.nextInt(10) - 5,
        isConnectable: false,
        observedAt: now,
      ),
      RadioScanResult(
        id: 'fake:aa:bb:cc:02',
        name: 'AirPods Pro',
        rssi: -55 + _random.nextInt(10) - 5,
        isConnectable: true,
        observedAt: now,
      ),
    ];
  }

  List<RadioScanResult> _mediumRiskBatch(DateTime now) {
    return [
      ..._benignBatch(now),
      RadioScanResult(
        id: 'fake:medium:01',
        name: 'Meta Smart Glasses',
        rssi: -85,
        isConnectable: false,
        observedAt: now,
      ),
    ];
  }

  static RadioScanResult _suspiciousDevice(DateTime now) {
    return RadioScanResult(
      id: 'fake:dd:ee:ff:03',
      name: 'Ray-Ban Meta',
      rssi: -40,
      isConnectable: true,
      observedAt: now,
    );
  }

  /// One batch that should score medium or high (UAT / debug inject).
  static List<RadioScanResult> highRiskBatch({DateTime? observedAt}) {
    final now = observedAt ?? DateTime.now();
    return [
      RadioScanResult(
        id: 'fake:aa:bb:cc:01',
        name: 'JBL Flip 6',
        rssi: -65,
        isConnectable: false,
        observedAt: now,
      ),
      _suspiciousDevice(now),
    ];
  }
}
