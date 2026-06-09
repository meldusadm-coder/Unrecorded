/// A single result from a radio scan cycle.
///
/// Maps to [DetectedSignal] in the core package when passed to the
/// scoring engine.
class RadioScanResult {
  /// Device identifier (e.g. BLE remote ID).
  final String id;

  /// Advertised device name, if available.
  final String? name;

  /// Signal strength in dBm.
  final int? rssi;

  /// Advertised service UUIDs.
  final List<String> serviceUuids;

  /// Bluetooth SIG company IDs from manufacturer-specific data (no payloads).
  final List<int> manufacturerIds;

  /// Whether the device is connectable.
  final bool isConnectable;

  /// When this result was observed.
  final DateTime observedAt;

  const RadioScanResult({
    required this.id,
    this.name,
    this.rssi,
    this.serviceUuids = const [],
    this.manufacturerIds = const [],
    this.isConnectable = false,
    required this.observedAt,
  });
}
