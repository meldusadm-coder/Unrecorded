import 'dart:async';

import '../radio_scan_result.dart';
import '../radio_scanner.dart';
import '../radio_scanner_exception.dart';
import '../radio_start_result.dart';
import '../radio_stop_result.dart';

/// Deterministic test scanner with explicit batch/error emission controls.
///
/// Supports delayed/gated start and injectable stop failures for contract and
/// manager tests.
class ScriptedRadioScanner implements RadioScanner {
  ScriptedRadioScanner({
    this.startDelay = Duration.zero,
    this.startFailure,
    this.stopFailure,
    this.stopFailureMayStillBeScanning = true,
  });

  /// Artificial delay before [start] confirms success (or failure).
  final Duration startDelay;

  /// When set, [start] returns [RadioStartFailed] after [startDelay].
  final RadioScannerException? startFailure;

  /// When set, [stop] returns [RadioStopFailed] instead of stopping.
  final RadioScannerException? stopFailure;

  /// [RadioStopFailed.mayStillBeScanning] when [stopFailure] is set.
  final bool stopFailureMayStillBeScanning;

  /// Optional gate: when set, [start] waits until [releaseStart] is called.
  Completer<void>? _startGate;

  StreamController<List<RadioScanResult>>? _controller;
  bool _scanning = false;
  bool _cancelRequested = false;
  Future<void> _chain = Future<void>.value();

  @override
  bool get isScanning => _scanning;

  /// Hold [start] until [releaseStart] (or [failPendingStart]) is called.
  void holdStart() {
    _startGate = Completer<void>();
  }

  /// Release a held [start] so it can complete normally (or with [startFailure]).
  void releaseStart() {
    final gate = _startGate;
    if (gate != null && !gate.isCompleted) {
      gate.complete();
    }
  }

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
          const RadioScannerException('Scripted scan already active.'),
          mayStillBeScanning: true,
        );
      }

      _cancelRequested = false;

      if (startDelay > Duration.zero) {
        await Future<void>.delayed(startDelay);
      }

      final startGate = _startGate;
      if (startGate != null && !startGate.isCompleted) {
        await startGate.future;
      }

      if (_cancelRequested) {
        return RadioStartCancelledAndStopped();
      }

      final failure = startFailure;
      if (failure != null) {
        return RadioStartFailed(failure, mayStillBeScanning: false);
      }

      _controller = StreamController<List<RadioScanResult>>.broadcast();
      _scanning = true;
      return RadioStarted(_controller!.stream);
    });
  }

  /// Emit a batch into the active scan stream.
  void emit(List<RadioScanResult> batch) {
    final controller = _controller;
    if (controller == null || controller.isClosed) return;
    controller.add(batch);
  }

  /// Emit a stream error into the active scan stream.
  void emitError(Object error, [StackTrace? stackTrace]) {
    final controller = _controller;
    if (controller == null || controller.isClosed) return;
    controller.addError(error, stackTrace);
  }

  /// Completes the active scan stream.
  Future<void> complete() async {
    final controller = _controller;
    if (controller == null || controller.isClosed) return;
    // Mark inactive before close so onCancel → stop() is a no-op and does not
    // race with ScannerManager's within-window restart.
    _controller = null;
    _scanning = false;
    await controller.close();
  }

  @override
  Future<RadioStopResult> stop() {
    _cancelRequested = true;
    // Unblock a held start so cancellation can be observed.
    releaseStart();
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
}
