/// A single radio signal observation from a scan cycle.
class DetectedSignal {
  /// Unique identifier for this signal (e.g. a MAC address or scan-local id).
  final String id;

  /// Human-readable name advertised by the device, if any.
  final String? displayName;

  /// Received signal-strength indicator in dBm. Closer to 0 = stronger.
  final int? rssi;

  /// BLE service UUIDs or other protocol identifiers advertised.
  final List<String> serviceIds;

  /// When this signal was last observed.
  final DateTime seenAt;

  /// Whether the device is advertising as connectable.
  final bool isConnectable;

  const DetectedSignal({
    required this.id,
    this.displayName,
    this.rssi,
    this.serviceIds = const [],
    required this.seenAt,
    this.isConnectable = false,
  });

  @override
  String toString() =>
      'DetectedSignal(id: $id, name: $displayName, rssi: $rssi)';
}
