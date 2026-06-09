import '../detection/detection_assessment.dart';
import '../detection/detection_evidence.dart';

/// Privacy-safe reason keys for a recent possible-risk reminder.
///
/// Only enum keys are persisted — display strings come from [AppCopy].
enum RecentRiskReason {
  matchedKnownPattern,
  repeatedSighting,
  strongSignal,
  connectable,
  addressPrefixHint,
}

/// Stable display order for de-duplicated reason lists.
const recentRiskReasonStableOrder = <RecentRiskReason>[
  RecentRiskReason.matchedKnownPattern,
  RecentRiskReason.addressPrefixHint,
  RecentRiskReason.repeatedSighting,
  RecentRiskReason.strongSignal,
  RecentRiskReason.connectable,
];

const _maxRecentRiskReasons = 4;

/// Maps contributing assessments to allowlisted [RecentRiskReason] keys.
///
/// Reads structured [DetectionEvidenceKind] only — never free-text labels.
List<RecentRiskReason> recentRiskReasonsForAssessments(
  List<DetectionAssessment> assessments,
) {
  final found = <RecentRiskReason>{};
  for (final assessment in assessments) {
    if (!assessment.contributesToRisk) continue;
    for (final evidence in assessment.evidence) {
      final reason = _reasonForEvidenceKind(evidence.kind);
      if (reason != null) found.add(reason);
    }
  }

  final ordered = <RecentRiskReason>[];
  for (final reason in recentRiskReasonStableOrder) {
    if (found.contains(reason)) ordered.add(reason);
    if (ordered.length >= _maxRecentRiskReasons) break;
  }
  return ordered;
}

RecentRiskReason? _reasonForEvidenceKind(DetectionEvidenceKind kind) {
  return switch (kind) {
    DetectionEvidenceKind.nameMatch ||
    DetectionEvidenceKind.serviceUuidHint ||
    DetectionEvidenceKind.manufacturerIdHint =>
      RecentRiskReason.matchedKnownPattern,
    DetectionEvidenceKind.addressPrefixHint =>
      RecentRiskReason.addressPrefixHint,
    DetectionEvidenceKind.repeatedSighting => RecentRiskReason.repeatedSighting,
    DetectionEvidenceKind.strongSignal => RecentRiskReason.strongSignal,
    DetectionEvidenceKind.connectable => RecentRiskReason.connectable,
    DetectionEvidenceKind.benignName || DetectionEvidenceKind.unknown => null,
  };
}

/// Parses a stored reason key; unknown names return null.
RecentRiskReason? recentRiskReasonFromStorage(String? name) {
  if (name == null || name.isEmpty) return null;
  for (final reason in RecentRiskReason.values) {
    if (reason.name == name) return reason;
  }
  return null;
}

const _maxSanitizedLabelLength = 80;

final _macPattern = RegExp(
  r'(?:[0-9a-f]{2}[:-]){5}[0-9a-f]{2}',
  caseSensitive: false,
);
final _uuidPattern = RegExp(
  r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
  caseSensitive: false,
);
final _longHexPattern = RegExp(r'[0-9a-f]{6,}', caseSensitive: false);
final _rawIdPattern = RegExp(r'\b0x[0-9a-f]+\b', caseSensitive: false);

/// Defence-in-depth guard for any human-readable label before persistence.
///
/// With enum-only storage this should not be used on the write path, but
/// remains available for validation.
String? sanitizeRecentRiskReasonLabel(String label) {
  final trimmed = label.trim();
  if (trimmed.isEmpty) return null;
  if (_macPattern.hasMatch(trimmed)) return null;
  if (_uuidPattern.hasMatch(trimmed)) return null;
  if (_longHexPattern.hasMatch(trimmed)) return null;
  if (_rawIdPattern.hasMatch(trimmed)) return null;
  if (trimmed.length > _maxSanitizedLabelLength) {
    return trimmed.substring(0, _maxSanitizedLabelLength);
  }
  return trimmed;
}
