import 'radio_scan_result.dart';

/// Abstract scanner interface.
///
/// Implementations include [FakeRadioScanner] (for demo/testing) and
/// [BleRadioScanner] (for real BLE hardware).
abstract class RadioScanner {
  /// Begin scanning and emit results as they are discovered.
  ///
  /// The stream may emit multiple results per scan cycle. Call [stop]
  /// to end scanning. Implementations should stop delivering further batches
  /// once [stop] completes.
  Stream<List<RadioScanResult>> scan();

  /// Stop an active scan. Safe to call even if not scanning.
  ///
  /// Contract: after [stop] completes, [isScanning] must be `false` and no
  /// further scan batches should be emitted.
  Future<void> stop();

  /// Whether a scan is currently in progress.
  bool get isScanning;
}
