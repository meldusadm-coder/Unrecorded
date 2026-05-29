/// A known smart-glasses or wearable-recording indicator in the local catalogue.
///
/// Signatures are matched locally against BLE advertisement data. A match
/// suggests possible recording risk — never proof of recording.
class DetectionSignature {
  const DetectionSignature({
    required this.id,
    required this.brandFamily,
    this.nameKeywords = const [],
    this.serviceUuidHints = const [],
    this.macPrefixHints = const [],
    required this.confidenceWeight,
    required this.matchExplanation,
    this.macPrefixExplanation,
  });

  /// Stable identifier for tests and logging.
  final String id;

  /// Brand or product family (e.g. "Meta / Ray-Ban").
  final String brandFamily;

  /// Case-insensitive substrings matched against [DetectedSignal.displayName].
  final List<String> nameKeywords;

  /// Normalized BLE service UUID hints (16- or 128-bit forms).
  final List<String> serviceUuidHints;

  /// Lowercase hex MAC address prefixes (no separators).
  final List<String> macPrefixHints;

  /// Base score contribution when this signature matches (0–100 scale).
  final int confidenceWeight;

  /// Plain-English explanation shown when matched by name or service UUID.
  final String matchExplanation;

  /// Optional explanation when matched only by MAC prefix; falls back to
  /// [matchExplanation] when null.
  final String? macPrefixExplanation;

  String explanationForMacPrefix() => macPrefixExplanation ?? matchExplanation;
}
