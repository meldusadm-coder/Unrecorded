import 'dart:async';
import 'dart:math';

import 'fake_demo_scenario.dart';
import 'radio_scan_result.dart';
import 'radio_scanner.dart';
import 'radio_scanner_exception.dart';
import 'radio_start_result.dart';
import 'radio_stop_result.dart';

/// A fake scanner that emits realistic sample data.
///
/// Use this when BLE hardware is unavailable (emulator, tests, demo mode).
class FakeRadioScanner implements RadioScanner {
  FakeRadioScanner({
    this.scenario = FakeDemoScenario.random,
    Random? random,
    this.tickInterval = const Duration(seconds: 3),
    this.startDelay = Duration.zero,
    this.startFailure,
    this.stopFailure,
    this.stopFailureMayStillBeScanning = true,
  }) : _random = random ?? Random();

  final FakeDemoScenario scenario;
  final Duration tickInterval;

  /// Artificial delay before [start] confirms success (or failure).
  final Duration startDelay;

  /// When set, [start] returns [RadioStartFailed] after [startDelay].
  final RadioScannerException? startFailure;

  /// When set, [stop] returns [RadioStopFailed] instead of stopping.
  final RadioScannerException? stopFailure;

  /// [RadioStopFailed.mayStillBeScanning] when [stopFailure] is set.
  final bool stopFailureMayStillBeScanning;

  StreamController<List<RadioScanResult>>? _controller;
  Timer? _timer;
  final Random _random;
  bool _scanning = false;
  bool _cancelRequested = false;
  Future<void> _chain = Future<void>.value();

  @override
  bool get isScanning => _scanning;

  Future<T> _serialized<T>(Future<T> Function() action) async {
    final previous = _chain;
    final gate = Completer<void>();
    _chain = gate.future;
    try {
      await previous;
      return await action();
    } finally {
      gate.complete();
    }
  }

  @override
  Future<RadioStartResult> start() {
    return _serialized(() async {
      if (_scanning) {
        return RadioStartFailed(
          const RadioScannerException('Fake scan already active.'),
          mayStillBeScanning: true,
        );
      }

      _cancelRequested = false;

      if (startDelay > Duration.zero) {
        await Future<void>.delayed(startDelay);
      }

      if (_cancelRequested) {
        return RadioStartCancelledAndStopped();
      }

      final failure = startFailure;
      if (failure != null) {
        return RadioStartFailed(failure, mayStillBeScanning: false);
      }

      _controller = StreamController<List<RadioScanResult>>.broadcast(
        onListen: _startEmitting,
      );
      _scanning = true;
      return RadioStarted(_controller!.stream);
    });
  }

  @override
  Future<RadioStopResult> stop() {
    _cancelRequested = true;
    // Cancel emission immediately so in-flight timer ticks cannot deliver
    // batches after stop is requested (before the serialized stop runs).
    _timer?.cancel();
    _timer = null;
    return _serialized(() async {
      if (!_scanning) {
        return RadioAlreadyStopped();
      }

      final failure = stopFailure;
      if (failure != null) {
        return RadioStopFailed(
          failure,
          mayStillBeScanning: stopFailureMayStillBeScanning,
        );
      }

      // Mark inactive before close so onCancel → stop() does not race with
      // the serialized stop body (and does not double-close).
      final controller = _controller;
      _controller = null;
      _scanning = false;
      _cancelRequested = false;
      if (controller != null && !controller.isClosed) {
        await controller.close();
      }
      return RadioStopped();
    });
  }

  void _startEmitting() {
    // Avoid duplicate timers if a second listener attaches.
    if (_timer != null) return;
    _timer = Timer.periodic(tickInterval, (_) {
      if (_cancelRequested ||
          !_scanning ||
          _controller == null ||
          _controller!.isClosed) {
        return;
      }
      _controller!.add(_generateBatch());
    });

    if (!_cancelRequested &&
        _controller != null &&
        !_controller!.isClosed) {
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
