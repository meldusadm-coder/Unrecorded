/// BLE / permission readiness failures before a scan session may start.
///
/// Pure Dart — no Flutter imports — so main and task isolates can share it.
enum ScanPreflightFailure {
  permissionDenied,
  permissionPermanentlyDenied,
  bluetoothUnsupported,
  bluetoothOff,
}
