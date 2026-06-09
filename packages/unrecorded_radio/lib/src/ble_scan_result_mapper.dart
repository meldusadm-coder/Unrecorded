import 'radio_scan_result.dart';

/// BLE advertisement details extracted from platform scan results.
class BleAdvertisement {
  const BleAdvertisement({
    required this.id,
    this.advertisedName,
    this.platformName,
    this.rssi,
    this.serviceUuids = const [],
    this.manufacturerIds = const [],
    this.isConnectable = false,
  });

  final String id;
  final String? advertisedName;
  final String? platformName;
  final int? rssi;
  final List<String> serviceUuids;
  final List<int> manufacturerIds;
  final bool isConnectable;
}

String? _normalizedName(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

/// Converts BLE advertisement details into a normalized [RadioScanResult].
RadioScanResult mapBleAdvertisement(
  BleAdvertisement advertisement, {
  DateTime? observedAt,
}) {
  final name = _normalizedName(advertisement.advertisedName) ??
      _normalizedName(advertisement.platformName);
  return RadioScanResult(
    id: advertisement.id,
    name: name,
    rssi: advertisement.rssi,
    serviceUuids: advertisement.serviceUuids,
    manufacturerIds: advertisement.manufacturerIds,
    isConnectable: advertisement.isConnectable,
    observedAt: observedAt ?? DateTime.now(),
  );
}
