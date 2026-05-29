import '../models/detected_signal.dart';
import 'signal_observation.dart';

/// Merged in-session record for one nearby signal identity.
class TrackedSignal {
  TrackedSignal({
    required this.stableKey,
    required this.id,
    required this.firstSeenAt,
    required this.lastSeenAt,
    this.displayName,
    this.lastRssi,
    this.smoothedRssi,
    this.serviceIds = const [],
    this.sightingCount = 1,
    this.everConnectable = false,
    this.normalizedMac,
  });

  final String stableKey;
  final String id;
  final DateTime firstSeenAt;
  DateTime lastSeenAt;
  String? displayName;
  int? lastRssi;
  double? smoothedRssi;
  List<String> serviceIds;
  int sightingCount;
  bool everConnectable;
  final String? normalizedMac;

  static const _smoothingAlpha = 0.3;

  factory TrackedSignal.fromObservation(SignalObservation obs) {
    final smoothed = obs.rssi?.toDouble();
    return TrackedSignal(
      stableKey: obs.stableKey,
      id: obs.id,
      firstSeenAt: obs.observedAt,
      lastSeenAt: obs.observedAt,
      displayName: obs.displayName,
      lastRssi: obs.rssi,
      smoothedRssi: smoothed,
      serviceIds: List<String>.from(obs.serviceIds),
      sightingCount: 1,
      everConnectable: obs.isConnectable,
      normalizedMac: obs.normalizedMac,
    );
  }

  void mergeObservation(SignalObservation obs) {
    lastSeenAt = obs.observedAt;
    sightingCount++;
    if (obs.displayName != null && obs.displayName!.trim().isNotEmpty) {
      displayName = obs.displayName;
    }
    if (obs.rssi != null) {
      lastRssi = obs.rssi;
      final rssi = obs.rssi!.toDouble();
      smoothedRssi = smoothedRssi == null
          ? rssi
          : _smoothingAlpha * rssi + (1 - _smoothingAlpha) * smoothedRssi!;
    }
    if (obs.isConnectable) everConnectable = true;
    for (final uuid in obs.serviceIds) {
      if (!serviceIds.contains(uuid)) serviceIds.add(uuid);
    }
  }

  DetectedSignal toDetectedSignal() {
    return DetectedSignal(
      id: id,
      displayName: displayName,
      rssi: lastRssi,
      serviceIds: List.unmodifiable(serviceIds),
      seenAt: lastSeenAt,
      isConnectable: everConnectable,
    );
  }
}
