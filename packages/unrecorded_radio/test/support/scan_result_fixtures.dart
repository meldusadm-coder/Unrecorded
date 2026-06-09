import 'package:unrecorded_radio/unrecorded_radio.dart';

/// A minimal [RadioScanResult] with only an id and a fixed timestamp.
RadioScanResult minimalResult(String id) =>
    RadioScanResult(id: id, observedAt: DateTime(2025, 1, 1));

/// A [RadioScanResult] with name, rssi, and connectable flag set.
RadioScanResult namedResult({
  required String id,
  required String name,
  int rssi = -70,
  bool connectable = false,
  List<String> serviceUuids = const [],
  List<int> manufacturerIds = const [],
}) =>
    RadioScanResult(
      id: id,
      name: name,
      rssi: rssi,
      isConnectable: connectable,
      serviceUuids: serviceUuids,
      manufacturerIds: manufacturerIds,
      observedAt: DateTime(2025, 1, 1),
    );
