import 'dart:async';
import 'dart:math';

import 'radio_scan_result.dart';
import 'radio_scanner.dart';

/// A fake scanner that emits realistic sample data.
///
/// Use this when BLE hardware is unavailable (emulator, tests, demo mode).
class FakeRadioScanner implements RadioScanner {
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

    // Emit an initial batch immediately.
    if (_controller != null && !_controller!.isClosed) {
      _controller!.add(_generateBatch());
    }
  }

  List<RadioScanResult> _generateBatch() {
    final now = DateTime.now();
    final results = <RadioScanResult>[
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

    // Occasionally include a suspicious device.
    if (_random.nextInt(3) == 0) {
      results.add(
        RadioScanResult(
          id: 'fake:dd:ee:ff:03',
          name: 'Ray-Ban Meta',
          rssi: -40 + _random.nextInt(20) - 10,
          isConnectable: true,
          observedAt: now,
        ),
      );
    }

    // Sometimes add an unnamed device.
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
}
