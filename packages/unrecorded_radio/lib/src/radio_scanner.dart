import 'radio_scan_result.dart';

/// Abstract scanner interface.
///
/// Implementations include [FakeRadioScanner] (for demo/testing) and
/// [BleRadioScanner] (for real BLE hardware).
abstract class RadioScanner {
  /// Begin scanning and emit results as they are discovered.
  ///
  /// The stream may emit multiple results per scan cycle. Call [stop]
  /// to end scanning.
  Stream<List<RadioScanResult>> scan();

  /// Stop an active scan. Safe to call even if not scanning.
  Future<void> stop();

  /// Whether a scan is currently in progress.
  bool get isScanning;
}
