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

  /// True when a stop failed with possible-active radio retained.
  bool _uncertainActive = false;

  bool get isRunning => _running;
  bool get inScanWindow => _inScanWindow;

  /// Whether the last stop left a possibly still-active scanner lease.
  bool get hasUncertainActiveScanner => _uncertainActive;

  /// Starts cadence. Returns a typed radio start outcome for the first window.
  Future<RadioStartResult?> start() async {
    if (_running || _uncertainActive) {
      return null; // already active / uncertain â€” caller maps to alreadyActive
    }
    return _beginScanWindow(isInitialStart: true);
  }

  /// Stops cadence. Returns the last radio stop result when a scanner existed.
  Future<RadioStopResult?> stop() async {
    _running = false;
    _cancelRestTimers();
    _windowTimer?.cancel();
    _windowTimer = null;
    final endedCleanly = await _endScanWindow();
    if (!endedCleanly) {
      return RadioStopFailed(
        const RadioScannerException('Scanner stop left possible-active radio.'),
        mayStillBeScanning: _uncertainActive,
      );
    }
    return _uncertainActive
        ? RadioStopFailed(
            const RadioScannerException(
              'Scanner stop left possible-active radio.',
            ),
            mayStillBeScanning: true,
          )
        : RadioStopped();
  }

  Future<RadioStartResult?> _beginScanWindow({
    bool isInitialStart = false,
  }) async {
    if (_uncertainActive) return null;
    if (!isInitialStart && !_running) return null;

    final previousStop = await _stopOwnedScanner();
    if (previousStop is RadioStopFailed) {
      _haltOnUncertainStop(previousStop);
      return RadioStartFailed(
        previousStop.error,
        mayStillBeScanning: previousStop.mayStillBeScanning,
      );
    }

    // User may have stopped while the previous stop awaited.
    if (!isInitialStart && !_running) return null;

    _cancelRestTimers();
    _scanner = _scannerFactory();
    final priorSub = _subscription;
    _subscription = null;
    unawaited(priorSub?.cancel());

    final startResult = await _scanner!.start();

    // User may have stopped while start awaited.
    if (!isInitialStart && !_running) {
      await _abandonStartedScanner(startResult);
      return startResult;
    }

    switch (startResult) {
      case RadioStarted(:final batches):
        _running = true;
        _inScanWindow = true;
        onScanWindowStart?.call();
        _subscription = batches.listen(
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
      case RadioStartCancelledAndStopped():
        _scanner = null;
        _inScanWindow = false;
        if (!isInitialStart) {
          _haltCadence();
        }
      case RadioStartFailed(:final error, :final mayStillBeScanning):
        _inScanWindow = false;
        if (mayStillBeScanning) {
          _uncertainActive = true;
        } else {
          _scanner = null;
        }
        if (!isInitialStart) {
          _haltCadence();
        }
        onError?.call(error);
    }
    return startResult;
  }

  Future<void> _abandonStartedScanner(RadioStartResult startResult) async {
    if (startResult is RadioStarted) {
      final stopResult = await _stopOwnedScanner();
      if (stopResult is RadioStopFailed) {
        _haltOnUncertainStop(stopResult);
      }
    } else if (startResult is RadioStartFailed &&
        startResult.mayStillBeScanning) {
      _uncertainActive = true;
      onError?.call(startResult.error);
    } else {
      _scanner = null;
    }
  }

  Future<void> _restartWithinWindow() async {
    if (!_running || !_inScanWindow || _uncertainActive) return;

    final stopResult = await _stopOwnedScanner();
    final sub = _subscription;
    _subscription = null;
    unawaited(sub?.cancel());

    if (stopResult is RadioStopFailed) {
      _haltOnUncertainStop(stopResult);
      return;
    }
    if (!_running || !_inScanWindow) return;

    _scanner = _scannerFactory();
    final startResult = await _scanner!.start();
    if (!_running || !_inScanWindow) {
      await _abandonStartedScanner(startResult);
      return;
    }

    switch (startResult) {
      case RadioStarted(:final batches):
        _subscription = batches.listen(
          onBatch,
          onError: (e) => onError?.call(e),
          onDone: () {
            if (_running && _inScanWindow) {
              unawaited(_restartWithinWindow());
            }
          },
        );
      case RadioStartCancelledAndStopped():
        _scanner = null;
        _haltCadence();
        _inScanWindow = false;
      case RadioStartFailed(:final error, :final mayStillBeScanning):
        if (mayStillBeScanning) {
          _uncertainActive = true;
        } else {
          _scanner = null;
        }
        _haltCadence();
        _inScanWindow = false;
        onError?.call(error);
    }
  }

  Future<void> _endScanWindowAndRest() async {
    if (!_running) return;
    final endedCleanly = await _endScanWindow();
    if (!_running || !endedCleanly) return;

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

  /// Ends the scan window. Returns false if stop left possible-active radio.
  Future<bool> _endScanWindow() async {
    if (_inScanWindow) {
      _inScanWindow = false;
    }
    _windowTimer?.cancel();
    _windowTimer = null;

    // Stop the radio before cancelling the subscription so an explicit stop
    // result (including stopFailure) is observed without cancel races.
    final stopResult = await _stopOwnedScanner();
    // Do not await cancel â€” under fakeAsync a pending cancel Future can stall
    // the cadence teardown. Dropping the subscription is enough to detach.
    final sub = _subscription;
    _subscription = null;
    unawaited(sub?.cancel());

    if (stopResult is RadioStopFailed) {
      _haltOnUncertainStop(stopResult);
      return false;
    }
    return true;
  }

  Future<RadioStopResult?> _stopOwnedScanner() async {
    final scanner = _scanner;
    if (scanner == null) return null;
    final result = await scanner.stop();
    if (result is! RadioStopFailed) {
      _scanner = null;
    }
    return result;
  }

  void _haltOnUncertainStop(RadioStopFailed result) {
    _uncertainActive = result.mayStillBeScanning;
    _haltCadence();
    _inScanWindow = false;
    onError?.call(result.error);
  }

  void _haltCadence() {
    _running = false;
    _cancelRestTimers();
    _windowTimer?.cancel();
    _windowTimer = null;
  }
}

