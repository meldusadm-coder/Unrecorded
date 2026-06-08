import 'package:test/test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';

import 'support/signal_fixtures.dart';

DetectionAssessment _assessment({
  required bool contributes,
  required List<DetectionEvidence> evidence,
}) {
  return DetectionAssessment(
    signal: makeTrackedSignal(id: 'test:01'),
    category: DeviceSignalCategory.possibleRecordingWearable,
    evidence: evidence,
    confidenceBand: ConfidenceBand.moderate,
    contributesToRisk: contributes,
    primaryMatchKind: SignatureMatchKind.name,
  );
}

void main() {
  test('maps evidence kinds to enum keys', () {
    final reasons = recentRiskReasonsForAssessments([
      _assessment(
        contributes: true,
        evidence: const [
          DetectionEvidence(
            kind: DetectionEvidenceKind.nameMatch,
            label: 'Ray-Ban Meta name match',
          ),
          DetectionEvidence(
            kind: DetectionEvidenceKind.repeatedSighting,
            label: 'Seen repeatedly nearby (4 times)',
          ),
          DetectionEvidence(
            kind: DetectionEvidenceKind.strongSignal,
            label: 'Strong nearby signal',
          ),
          DetectionEvidence(
            kind: DetectionEvidenceKind.connectable,
            label: 'Device is connectable',
          ),
        ],
      ),
    ]);
    expect(reasons, [
      RecentRiskReason.matchedKnownPattern,
      RecentRiskReason.repeatedSighting,
      RecentRiskReason.strongSignal,
      RecentRiskReason.connectable,
    ]);
    for (final reason in reasons) {
      expect(reason.name, isNot(contains('Ray-Ban')));
    }
  });

  test('drops benignName unknown and non-contributing assessments', () {
    final reasons = recentRiskReasonsForAssessments([
      _assessment(
        contributes: false,
        evidence: const [
          DetectionEvidence(
            kind: DetectionEvidenceKind.benignName,
            label: 'Name suggests audio',
          ),
        ],
      ),
      _assessment(
        contributes: true,
        evidence: const [
          DetectionEvidence(
            kind: DetectionEvidenceKind.unknown,
            label: 'Unknown nearby signal',
          ),
        ],
      ),
    ]);
    expect(reasons, isEmpty);
  });

  test('de-dupes and caps at four reasons', () {
    final reasons = recentRiskReasonsForAssessments([
      _assessment(
        contributes: true,
        evidence: const [
          DetectionEvidence(
            kind: DetectionEvidenceKind.nameMatch,
            label: 'Match A',
          ),
          DetectionEvidence(
            kind: DetectionEvidenceKind.serviceUuidHint,
            label: 'Match B',
          ),
        ],
      ),
      _assessment(
        contributes: true,
        evidence: const [
          DetectionEvidence(
            kind: DetectionEvidenceKind.addressPrefixHint,
            label: 'Prefix hint',
          ),
          DetectionEvidence(
            kind: DetectionEvidenceKind.repeatedSighting,
            label: 'Seen again',
          ),
          DetectionEvidence(
            kind: DetectionEvidenceKind.strongSignal,
            label: 'Strong',
          ),
          DetectionEvidence(
            kind: DetectionEvidenceKind.connectable,
            label: 'Connectable',
          ),
        ],
      ),
    ]);
    expect(reasons.length, lessThanOrEqualTo(4));
    expect(reasons.toSet().length, reasons.length);
  });

  test('sanitizeRecentRiskReasonLabel drops identifiers and caps length', () {
    expect(
      sanitizeRecentRiskReasonLabel('aa:bb:cc:dd:ee:ff'),
      isNull,
    );
    expect(
      sanitizeRecentRiskReasonLabel(
        '550e8400-e29b-41d4-a716-446655440000',
      ),
      isNull,
    );
    expect(
      sanitizeRecentRiskReasonLabel('deadbeefcafe'),
      isNull,
    );
    expect(
      sanitizeRecentRiskReasonLabel('Seen more than once nearby'),
      'Seen more than once nearby',
    );
    final long = 'Seen nearby signal ' * 5;
    expect(sanitizeRecentRiskReasonLabel(long)!.length, 80);
  });
}
