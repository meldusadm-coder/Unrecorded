import 'dart:async';

import 'package:unrecorded_radio/unrecorded_radio.dart';

import 'scanner_cadence_config.dart';

typedef ScanBatchCallback = void Function(List<RadioScanResult> batch);
typedef ScanPhaseCallback = void Function();
typedef ScanErrorCallback = void Function(Object error);

/// Sole owner of scan/rest cadence and radio subscription lifecycle.
class ScannerManager {
  ScannerManager({
    required RadioScanner Function() scannerFactory,
    this.cadence = defaultScannerCadence,
  }) : _scannerFactory = scannerFactory;

  final RadioScanner Function() _scannerFactory;
  final ScannerCadenceConfig cadence;

  ScanBatchCallback? onBatch;
  ScanPhaseCallback? onScanWindowStart;
  ScanPhaseCallback? onScanWindowEnd;
  ScanPhaseCallback? onRestTick;
  ScanErrorCallback? onError;

  RadioScanner? _scanner;
  StreamSubscription<List<RadioScanResult>>? _subscription;
  Timer? _windowTimer;
  Timer? _restEndTimer;
  Timer? _restTickTimer;
  bool _running = false;
  bool _inScanWindow = false;

  bool get isRunning => _running;
  bool get inScanWindow => _inScanWindow;

  Future<void> start() async {
    if (_running) return;
    _running = true;
    await _beginScanWindow();
  }

  Future<void> stop() async {
    _running = false;
    _cancelRestTimers();
    _windowTimer?.cancel();
    _windowTimer = null;
    await _endScanWindow();
  }

  Future<void> _beginScanWindow() async {
    if (!_running) return;
    _cancelRestTimers();
    _inScanWindow = true;
    onScanWindowStart?.call();

    await _scanner?.stop();
    _scanner = _scannerFactory();
    await _subscription?.cancel();
    _subscription = _scanner!.scan().listen(
          onBatch,
          onError: (e) => onError?.call(e),
          onDone: () {
            if (_running && _inScanWindow) {
              unawaited(_restartWithinWindow());
            }
          },
        );

    _windowTimer?.cancel();
    _windowTimer = Timer(cadence.scanWindow, () {
      unawaited(_endScanWindowAndRest());
    });
  }

  Future<void> _restartWithinWindow() async {
    if (!_running || !_inScanWindow) return;
    await _subscription?.cancel();
    _subscription = null;
    await _scanner?.stop();
    if (!_running || !_inScanWindow) return;
    _scanner = _scannerFactory();
    _subscription = _scanner!.scan().listen(
          onBatch,
          onError: (e) => onError?.call(e),
          onDone: () {
            if (_running && _inScanWindow) {
              unawaited(_restartWithinWindow());
            }
          },
        );
  }

  Future<void> _endScanWindowAndRest() async {
    if (!_running) return;
    await _endScanWindow();
    if (!_running) return;

    onScanWindowEnd?.call();

    _restTickTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      onRestTick?.call();
    });

    _restEndTimer = Timer(cadence.restInterval, () {
      _cancelRestTimers();
      if (_running) {
        unawaited(_beginScanWindow());
      }
    });
  }

  void _cancelRestTimers() {
    _restEndTimer?.cancel();
    _restEndTimer = null;
    _restTickTimer?.cancel();
    _restTickTimer = null;
  }

  Future<void> _endScanWindow() async {
    if (_inScanWindow) {
      _inScanWindow = false;
    }
    _windowTimer?.cancel();
    _windowTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    await _scanner?.stop();
    _scanner = null;
  }
}
