import 'tracked_signal.dart';

/// Immutable view of a [TrackedSignal] for UI and detection layers.
class TrackedSignalSnapshot {
  const TrackedSignalSnapshot({
    required this.stableKey,
    required this.id,
    required this.firstSeenAt,
    required this.lastSeenAt,
    this.displayName,
    this.lastRssi,
    this.smoothedRssi,
    this.serviceIds = const [],
    required this.sightingCount,
    required this.everConnectable,
    this.normalizedMac,
  });

  final String stableKey;
  final String id;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;
  final String? displayName;
  final int? lastRssi;
  final double? smoothedRssi;
  final List<String> serviceIds;
  final int sightingCount;
  final bool everConnectable;
  final String? normalizedMac;

  factory TrackedSignalSnapshot.fromTracked(TrackedSignal tracked) {
    return TrackedSignalSnapshot(
      stableKey: tracked.stableKey,
      id: tracked.id,
      firstSeenAt: tracked.firstSeenAt,
      lastSeenAt: tracked.lastSeenAt,
      displayName: tracked.displayName,
      lastRssi: tracked.lastRssi,
      smoothedRssi: tracked.smoothedRssi,
      serviceIds: List.unmodifiable(tracked.serviceIds),
      sightingCount: tracked.sightingCount,
      everConnectable: tracked.everConnectable,
      normalizedMac: tracked.normalizedMac,
    );
  }
}
