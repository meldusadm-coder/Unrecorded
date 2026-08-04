import 'package:unrecorded_core/unrecorded_core.dart';

/// Opaque identity for a live material-risk episode in the task isolate.
///
/// Used for notification identity and dismissal correlation. Never includes
/// BLE names, MACs, or raw scan payloads. The [fingerprint] stays task-local
/// and must never cross the task→main boundary.
class BackgroundRiskEpisode {
  const BackgroundRiskEpisode({
    required this.riskEpisodeId,
    required this.fingerprint,
    required this.riskLevelName,
    required this.startedAt,
  });

  /// Opaque episode id (monotonic counter or similar).
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

  /// Opens a new opaque episode for [fingerprint] / [riskLevel].
  factory BackgroundRiskEpisode.open({
    required String fingerprint,
    required RiskLevel riskLevel,
    required int sequence,
    DateTime? startedAt,
  }) {
    return BackgroundRiskEpisode(
      riskEpisodeId: 'ep-$sequence',
      fingerprint: fingerprint,
      riskLevelName: riskLevel.name,
      startedAt: startedAt ?? DateTime.now(),
    );
  }
}

/// Builds a task-local fingerprint from risk-contributing assessments only.
///
/// Stable keys and evidence stay inside the task isolate; only the opaque
/// [BackgroundRiskEpisode.riskEpisodeId] may cross the boundary.
String backgroundRiskFingerprint(List<DetectionAssessment> assessments) {
  final parts = <String>[];
  for (final a in assessments) {
    if (!a.contributesToRisk) continue;
    final evidenceKinds = a.evidence.map((e) => e.kind.name).toList()..sort();
    parts.add(
      [
        a.signal.stableKey,
        a.category.name,
        a.confidenceBand.name,
        evidenceKinds.join(','),
        a.primaryMatchKind?.name ?? '',
        a.matchedSignature?.id ?? '',
      ].join('|'),
    );
  }
  parts.sort();
  return parts.join(';');
}

/// Tracks open/close of material-risk episodes for the task isolate.
class BackgroundRiskEpisodeTracker {
  BackgroundRiskEpisode? _current;
  var _nextSequence = 1;

  BackgroundRiskEpisode? get current => _current;

  /// Updates episode identity for the current risk-contributing set.
  ///
  /// Returns the episode when risk is live; `null` when risk has cleared.
  BackgroundRiskEpisode? update({
    required List<DetectionAssessment> assessments,
    required RiskLevel riskLevel,
    required bool isLiveRisk,
  }) {
    if (!isLiveRisk) {
      _current = null;
      return null;
    }

    final fingerprint = backgroundRiskFingerprint(assessments);
    final existing = _current;
    if (existing != null && existing.fingerprint == fingerprint) {
      if (existing.riskLevelName != riskLevel.name) {
        _current = existing.copyWith(riskLevelName: riskLevel.name);
      }
      return _current;
    }

    _current = BackgroundRiskEpisode.open(
      fingerprint: fingerprint,
      riskLevel: riskLevel,
      sequence: _nextSequence++,
    );
    return _current;
  }

  void clear() {
    _current = null;
  }
}
