import '../models/detected_signal.dart';
import 'signal_stable_key.dart';

/// A single observation from one scan batch before session merge.
class SignalObservation {
  const SignalObservation({
    required this.stableKey,
    required this.id,
    this.displayName,
    this.rssi,
    this.serviceIds = const [],
    this.manufacturerIds = const [],
    required this.observedAt,
    this.isConnectable = false,
    this.normalizedMac,
  });

  final String stableKey;
  final String id;
  final String? displayName;
  final int? rssi;
  final List<String> serviceIds;
  final List<int> manufacturerIds;
  final DateTime observedAt;
  final bool isConnectable;
  final String? normalizedMac;

  factory SignalObservation.fromDetectedSignal(DetectedSignal signal) {
    return SignalObservation(
      stableKey: stableKeyFor(signal),
      id: signal.id,
      displayName: signal.displayName,
      rssi: signal.rssi,
      serviceIds: List.unmodifiable(signal.serviceIds),
      manufacturerIds: List.unmodifiable(signal.manufacturerIds),
      observedAt: signal.seenAt,
      isConnectable: signal.isConnectable,
      normalizedMac: normalizedMacFromId(signal.id),
    );
  }
}
