import 'dart:async';

import '../radio_scan_result.dart';
import '../radio_scanner.dart';

/// Deterministic test scanner with explicit batch/error emission controls.
class ScriptedRadioScanner implements RadioScanner {
  StreamController<List<RadioScanResult>>? _controller;
  bool _stopping = false;

  @override
  bool get isScanning => _controller != null && !_controller!.isClosed;

  @override
  Stream<List<RadioScanResult>> scan() {
    _controller = StreamController<List<RadioScanResult>>(
      onCancel: () => stop(),
    );
    return _controller!.stream;
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
    await controller.close();
  }

  @override
  Future<void> stop() async {
    if (_stopping) return;
    _stopping = true;
    final controller = _controller;
    if (controller == null) {
      _stopping = false;
      return;
    }
    if (!controller.isClosed) {
      await controller.close();
    }
    _controller = null;
    _stopping = false;
  }
}
