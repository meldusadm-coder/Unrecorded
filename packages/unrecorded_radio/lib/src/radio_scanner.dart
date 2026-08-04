import 'radio_start_result.dart';
import 'radio_stop_result.dart';

/// Abstract scanner interface.
///
/// Implementations include [FakeRadioScanner] (for demo/testing) and
/// [BleRadioScanner] (for real BLE hardware).
///
/// Lifecycle methods return typed results and do not throw expected scanner
/// failures across the package boundary.
abstract class RadioScanner {
  /// Begin scanning after platform start is confirmed.
  ///
  /// On [RadioStarted], subscribe to [RadioStarted.batches] for results.
  /// Call [stop] to end scanning. Implementations stop delivering further
  /// batches once a successful [stop] completes.
  Future<RadioStartResult> start();

  /// Stop an active scan. Safe to call even if not scanning.
  ///
  /// After a successful [RadioStopped] or [RadioAlreadyStopped], [isScanning]
  /// is `false` and no further scan batches should be emitted. A
  /// [RadioStopFailed] with [RadioStopFailed.mayStillBeScanning] true means
  /// the scanner must be treated as possibly still active.
  Future<RadioStopResult> stop();

  /// Whether a scan is currently in progress.
  ///
  /// True only after a successful start confirmation. Remains true after a
  /// failed stop that reports possible-active.
  bool get isScanning;
}
