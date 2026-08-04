import 'radio_scanner_exception.dart';

/// Outcome of [RadioScanner.stop]. Lifecycle failures are typed, not thrown.
sealed class RadioStopResult {
  const RadioStopResult();
}

/// Platform stop confirmed; scanner is inactive.
class RadioStopped extends RadioStopResult {
  const RadioStopped();
}

/// Stop was a no-op because the scanner was already inactive.
class RadioAlreadyStopped extends RadioStopResult {
  const RadioAlreadyStopped();
}

/// Stop failed. When [mayStillBeScanning] is true, treat as possible-active.
class RadioStopFailed extends RadioStopResult {
  RadioStopFailed(this.error, {required this.mayStillBeScanning});

  final RadioScannerException error;
  final bool mayStillBeScanning;
}
