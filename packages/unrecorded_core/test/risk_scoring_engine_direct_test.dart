import 'package:test/test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';

import 'support/certainty_language.dart';
import 'support/signal_fixtures.dart';

DetectionAssessment _addressOnlyAssessment({
  required String id,
  int? rssi,
}) {
  return DetectionAssessment(
    signal: makeTrackedSignal(id: id, rssi: rssi),
    category: DeviceSignalCategory.possibleRecordingWearable,
    matchedSignature: null,
    primaryMatchKind: null,
    confidenceBand: ConfidenceBand.moderate,
    contributesToRisk: true,
    evidence: const [
      DetectionEvidence(
        kind: DetectionEvidenceKind.addressPrefixHint,
        label:
            'A nearby Bluetooth address prefix may match a known wearable. This is not proof of recording.',
      ),
    ],
  );
}

void main() {
  group('RiskScoringEngine direct', () {
    test('empty snapshot returns low and no-signal reason', () {
      final result = RiskScoringEngine().evaluate(
        DetectionSnapshot(assessments: const [], capturedAt: DateTime(2025, 1)),
      );
      expect(result.level, RiskLevel.low);
      expect(result.totalScore, 0);
      expect(result.reasons, contains('No nearby signals detected.'));
    });

    test('best signal score wins among contributors', () {
      final engine = RiskScoringEngine();
      final assessments = DetectionEngine().assessAll([
        makeTrackedSignal(
          id: '11:22:33:44:55:66',
          name: 'Ray-Ban Meta',
          rssi: -42,
          sightings: 4,
          connectable: true,
        ),
        makeTrackedSignal(
          id: 'aa:bb:cc:dd:ee:ff',
          name: 'smart glasses',
          rssi: -84,
        ),
      ]);
      final result = engine.evaluate(
        DetectionSnapshot(
          assessments: assessments,
          capturedAt: DateTime(2025, 1),
        ),
      );

      expect(result.level, RiskLevel.high);
      expect(result.totalScore, greaterThanOrEqualTo(40));
      expect(result.reasons, isNotEmpty);
    });

    test('address-only hint contributes medium bounded score', () {
      final result = RiskScoringEngine().evaluate(
        DetectionSnapshot(
          assessments: [
            _addressOnlyAssessment(id: '00:0B:9A:12:34:56', rssi: -20),
          ],
          capturedAt: DateTime(2025, 1),
        ),
      );
      expect(result.totalScore, 20);
      expect(result.level, RiskLevel.medium);
    });

    test('mac-only matches are capped below high', () {
      final assessments = DetectionEngine().assessAll([
        makeTrackedSignal(
          id: '00:0B:9A:12:34:56',
          rssi: -35,
          sightings: 5,
          connectable: true,
        ),
      ]);
      final result = RiskScoringEngine().evaluate(
        DetectionSnapshot(
          assessments: assessments,
          capturedAt: DateTime(2025, 1),
        ),
      );
      expect(
        result.totalScore,
        lessThanOrEqualTo(
          defaultRiskScoringPolicy.maxSupportingOnlyMediumScore,
        ),
      );
      expect(result.level, isNot(RiskLevel.high));
    });

    test('reasons avoid certainty language', () {
      final assessments = DetectionEngine().assessAll([
        makeTrackedSignal(
          id: '11:22:33:44:55:66',
          name: 'Meta Smart Glasses',
          rssi: -40,
        ),
      ]);
      final result = RiskScoringEngine().evaluate(
        DetectionSnapshot(
          assessments: assessments,
          capturedAt: DateTime(2025, 1),
        ),
      );
      expect(result.reasons, isNotEmpty);
      for (final reason in result.reasons) {
        expectNoCertaintyLanguage(reason);
      }
    });
  });
}
