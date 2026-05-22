/// Represents the assessed privacy-risk level of a scan snapshot.
///
/// These levels communicate *possible* risk — never certainty.
enum RiskLevel {
  /// No suspicious signals detected.
  low,

  /// Some signals match patterns associated with smart glasses or
  /// wearable recording devices.
  medium,

  /// Strong or repeated signals closely match known recording-device
  /// patterns.
  high,
}
