import 'radio_scan_result.dart';
import 'radio_scanner_exception.dart';

/// Outcome of [RadioScanner.start]. Lifecycle failures are typed, not thrown.
sealed class RadioStartResult {}

/// Platform start confirmed; [batches] emits scan results until stop.
class RadioStarted extends RadioStartResult {
  RadioStarted(this.batches);

  final Stream<List<RadioScanResult>> batches;
}

/// Start was cancelled (e.g. stop during start) and the scanner is stopped.
class RadioStartCancelledAndStopped extends RadioStartResult {}

/// Start failed. When [mayStillBeScanning] is true, treat as possible-active.
class RadioStartFailed extends RadioStartResult {
  RadioStartFailed(this.error, {required this.mayStillBeScanning});

  final RadioScannerException error;
  final bool mayStillBeScanning;
}
