import 'package:test/test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';

void main() {
  group('detectionSignatures catalogue', () {
    test('every entry has required fields', () {
      expect(detectionSignatures, isNotEmpty);
      for (final signature in detectionSignatures) {
        expect(signature.id, isNotEmpty);
        expect(signature.brandFamily, isNotEmpty);
        expect(signature.confidenceWeight, inInclusiveRange(1, 100));
        expect(signature.matchExplanation, isNotEmpty);
        expect(
          signature.nameKeywords.isNotEmpty ||
              signature.serviceUuidHints.isNotEmpty ||
              signature.manufacturerIdHints.isNotEmpty ||
              signature.macPrefixHints.isNotEmpty,
          isTrue,
          reason: '${signature.id} must match on at least one field',
        );
        expect(
          signature.matchExplanation.toLowerCase(),
          isNot(contains('proof')),
        );
      }
    });

    test('ids are unique', () {
      final ids = detectionSignatures.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('verified manufacturer hints are present for Meta and Snap', () {
      final meta =
          detectionSignatures.firstWhere((s) => s.id == 'meta-ray-ban');
      final snap =
          detectionSignatures.firstWhere((s) => s.id == 'snap-spectacles');
      expect(meta.manufacturerIdHints, contains(0x0D53));
      expect(snap.manufacturerIdHints, contains(0x03C2));
    });
  });

  group('default catalogue pipeline', () {
    PipelineResult _evaluate(DetectedSignal signal) {
      final pipeline = DetectionPipeline();
      final now = signal.seenAt;
      return pipeline.processBatch([signal], now);
    }

    test('name keyword matches through default SignatureMatcher', () {
      final now = DateTime(2025, 6, 1, 12, 0, 0);
      final result = _evaluate(
        DetectedSignal(
          id: 'aa:bb:cc:dd:ee:ff',
          displayName: 'Ray-Ban Meta',
          seenAt: now,
        ),
      );
      expect(result.scoring.level, RiskLevel.medium);
      expect(result.scoring.totalScore, greaterThanOrEqualTo(15));
    });

    test('address prefix matches through default SignatureMatcher', () {
      final now = DateTime(2025, 6, 1, 12, 0, 0);
      final result = _evaluate(
        DetectedSignal(
          id: '00:0B:9A:12:34:56',
          seenAt: now,
        ),
      );
      expect(result.scoring.level, RiskLevel.medium);
      expect(
        result.scoring.totalScore,
        lessThanOrEqualTo(
            defaultRiskScoringPolicy.maxSupportingOnlyMediumScore),
      );
    });

    test('Snap manufacturer ID matches through default SignatureMatcher', () {
      final now = DateTime(2025, 6, 1, 12, 0, 0);
      final result = _evaluate(
        DetectedSignal(
          id: 'opaque-platform-id',
          manufacturerIds: [0x03C2],
          seenAt: now,
        ),
      );
      expect(result.scoring.level, RiskLevel.medium);
      expect(
        result.scoring.totalScore,
        lessThanOrEqualTo(
            defaultRiskScoringPolicy.maxSupportingOnlyMediumScore),
      );
      expect(result.scoring.level, isNot(RiskLevel.high));
    });

    test('benign headphone name stays low even with unrelated manufacturer ID',
        () {
      final now = DateTime(2025, 6, 1, 12, 0, 0);
      final result = _evaluate(
        DetectedSignal(
          id: 'aa:bb:cc:dd:ee:ff',
          displayName: 'JBL Flip 6',
          manufacturerIds: [0x004C],
          seenAt: now,
        ),
      );
      expect(result.scoring.level, RiskLevel.low);
      expect(result.scoring.totalScore, 0);
    });
  });
}
