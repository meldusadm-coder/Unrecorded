import 'package:unrecorded_core/unrecorded_core.dart';

/// Builds a [TrackedSignal] directly without a [ScanSession].
///
/// Useful in scoring and assessment tests that need a pre-built signal.
/// Tests that need the session-based lifecycle (detection engine tests) should
/// use [ScanSession.observe] instead so expiry/smoothing logic is exercised.
TrackedSignal makeTrackedSignal({
  required String id,
  String? name,
  int? rssi,
  int sightings = 1,
  bool connectable = false,
}) {
  final now = DateTime(2025, 1, 1);
  return TrackedSignal(
    stableKey: id,
    id: id,
    firstSeenAt: now,
    lastSeenAt: now,
    displayName: name,
    lastRssi: rssi,
    smoothedRssi: rssi?.toDouble(),
    sightingCount: sightings,
    everConnectable: connectable,
    normalizedMac: id.replaceAll(':', '').toLowerCase(),
  );
}
