/// Opaque identity for a live material-risk episode in the task isolate.
///
/// Used for notification identity and dismissal correlation. Never includes
/// BLE names, MACs, or raw scan payloads.
class BackgroundRiskEpisode {
  const BackgroundRiskEpisode({
    required this.riskEpisodeId,
    required this.fingerprint,
    required this.riskLevelName,
    required this.startedAt,
  });

  /// Opaque episode id (UUID or similar).
  final String riskEpisodeId;

  /// Canonical task-local fingerprint of contributing risk evidence.
  final String fingerprint;

  /// Wire name of [RiskLevel] at episode open.
  final String riskLevelName;

  final DateTime startedAt;

  BackgroundRiskEpisode copyWith({
    String? riskLevelName,
  }) {
    return BackgroundRiskEpisode(
      riskEpisodeId: riskEpisodeId,
      fingerprint: fingerprint,
      riskLevelName: riskLevelName ?? this.riskLevelName,
      startedAt: startedAt,
    );
  }
}
