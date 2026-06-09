/// A known smart-glasses or wearable-recording indicator in the local catalogue.
///
/// Signatures are matched locally against BLE advertisement data. A match
/// suggests possible recording risk — never proof of recording.
///
/// Evidence strength is encoded by match kind in scoring (name > service UUID >
/// manufacturer ID > address prefix), not by a per-signature weight field.
class DetectionSignature {
  const DetectionSignature({
    required this.id,
    required this.brandFamily,
    this.nameKeywords = const [],
    this.serviceUuidHints = const [],
    this.manufacturerIdHints = const [],
    this.macPrefixHints = const [],
    required this.confidenceWeight,
    required this.matchExplanation,
    this.macPrefixExplanation,
    this.sourceNote,
  });

  /// Stable identifier for tests and logging.
  final String id;

  /// Brand or product family (e.g. "Meta / Ray-Ban").
  final String brandFamily;

  /// Case-insensitive substrings matched against [DetectedSignal.displayName].
  final List<String> nameKeywords;

  /// Normalized BLE service UUID hints (16- or 128-bit forms).
  final List<String> serviceUuidHints;

  /// Bluetooth SIG company IDs (manufacturer-specific data keys only).
  final List<int> manufacturerIdHints;

  /// Lowercase hex address-prefix hints (OUI / MAC prefix, no separators).
  ///
  /// Weak supporting evidence — not proof of a specific device.
  final List<String> macPrefixHints;

  /// Base score contribution when this signature matches (0–100 scale).
  final int confidenceWeight;

  /// Plain-English explanation shown when matched by name or service UUID.
  final String matchExplanation;

  /// Optional explanation when matched only by address prefix; falls back to
  /// [matchExplanation] when null.
  final String? macPrefixExplanation;

  /// Short maintainer note: why hints exist; weak supporting evidence only.
  final String? sourceNote;

  String explanationForMacPrefix() => macPrefixExplanation ?? matchExplanation;
}
