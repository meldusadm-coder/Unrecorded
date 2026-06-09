import 'package:test/test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';

import 'support/certainty_language.dart';
import 'support/signal_fixtures.dart';

const _testSignatures = [
  DetectionSignature(
    id: 'test-brand-a',
    brandFamily: 'Test Brand A',
    nameKeywords: ['ray-ban'],
    serviceUuidHints: ['aaaa'],
    manufacturerIdHints: [0x00A1],
    macPrefixHints: ['000b9a'],
    confidenceWeight: 35,
    matchExplanation:
        'A nearby device may match Test Brand A based on its advertised name.',
    macPrefixExplanation:
        'A nearby address pattern may resemble a known device family. '
        'This is not proof of a specific device.',
  ),
  DetectionSignature(
    id: 'test-brand-b',
    brandFamily: 'Test Brand B',
    serviceUuidHints: ['bbbb'],
    manufacturerIdHints: [0x00B2],
    confidenceWeight: 30,
    matchExplanation:
        'A nearby device may match Test Brand B via a service hint.',
  ),
];

const _testMatcher = SignatureMatcher(signatures: _testSignatures);

PipelineResult _evaluate(DetectedSignal signal, {int sightings = 1}) {
  final pipeline = DetectionPipeline(
    detectionEngine: DetectionEngine(matcher: _testMatcher),
  );
  final base = DateTime(2025, 6, 1, 12, 0, 0);
  for (var i = 0; i < sightings; i++) {
    final seenAt = base.add(Duration(seconds: i * 3));
    pipeline.processBatch(
      [
        DetectedSignal(
          id: signal.id,
          displayName: signal.displayName,
          rssi: signal.rssi,
          serviceIds: signal.serviceIds,
          manufacturerIds: signal.manufacturerIds,
          seenAt: seenAt,
          isConnectable: signal.isConnectable,
        ),
      ],
      seenAt,
    );
  }
  return pipeline.expireAndEvaluate(base.add(Duration(seconds: sightings * 3)));
}

void main() {
  group('shouldConsiderAddressPrefix', () {
    test('rejects null, empty, UUID-like, and opaque IDs', () {
      expect(SignatureMatcher.shouldConsiderAddressPrefix(null), isFalse);
      expect(SignatureMatcher.shouldConsiderAddressPrefix(''), isFalse);
      expect(
        SignatureMatcher.shouldConsiderAddressPrefix(
          '550e8400-e29b-41d4-a716-446655440000',
        ),
        isFalse,
      );
      expect(
        SignatureMatcher.shouldConsiderAddressPrefix('opaque-platform-id'),
        isFalse,
      );
    });

    test('rejects locally administered and multicast addresses', () {
      expect(
        SignatureMatcher.shouldConsiderAddressPrefix('F2:11:22:33:44:55'),
        isFalse,
      );
      expect(
        SignatureMatcher.shouldConsiderAddressPrefix('01:00:5E:00:00:01'),
        isFalse,
      );
    });

    test('accepts canonical public unicast MAC', () {
      expect(
        SignatureMatcher.shouldConsiderAddressPrefix('00:0B:9A:12:34:56'),
        isTrue,
      );
    });
  });

  group('supporting evidence scoring', () {
    test('service-UUID-only stays medium and below high cap', () {
      final result = _evaluate(
        DetectedSignal(
          id: 'opaque-id',
          serviceIds: ['0000bbbb-0000-1000-8000-00805f9b34fb'],
          seenAt: DateTime(2025, 1, 1),
          rssi: -40,
          isConnectable: true,
        ),
        sightings: 5,
      );
      expect(result.scoring.level, RiskLevel.medium);
      expect(
        result.scoring.totalScore,
        lessThanOrEqualTo(
          defaultRiskScoringPolicy.maxSupportingOnlyMediumScore,
        ),
      );
      expect(result.scoring.level, isNot(RiskLevel.high));
    });

    test('unknown generic service UUID stays low', () {
      final result = _evaluate(
        DetectedSignal(
          id: 'aa:bb:cc:dd:ee:ff',
          serviceIds: ['180A'],
          seenAt: DateTime(2025, 1, 1),
        ),
      );
      expect(result.scoring.level, RiskLevel.low);
      expect(result.scoring.totalScore, 0);
    });

    test('manufacturer-ID-only stays medium and below high cap', () {
      final result = _evaluate(
        DetectedSignal(
          id: 'opaque-id',
          manufacturerIds: [0x00B2],
          seenAt: DateTime(2025, 1, 1),
          rssi: -35,
        ),
        sightings: 4,
      );
      expect(result.scoring.level, RiskLevel.medium);
      expect(
        result.scoring.totalScore,
        lessThanOrEqualTo(
          defaultRiskScoringPolicy.maxSupportingOnlyMediumScore,
        ),
      );
    });

    test('unknown manufacturer ID stays low', () {
      final result = _evaluate(
        DetectedSignal(
          id: 'aa:bb:cc:dd:ee:ff',
          manufacturerIds: [0xFFFF],
          seenAt: DateTime(2025, 1, 1),
        ),
      );
      expect(result.scoring.level, RiskLevel.low);
      expect(result.scoring.totalScore, 0);
    });

    test('address-prefix-only capped at maxSupportingOnlyMediumScore', () {
      final result = _evaluate(
        DetectedSignal(
          id: '00:0B:9A:12:34:56',
          seenAt: DateTime(2025, 1, 1),
          rssi: -35,
          isConnectable: true,
        ),
        sightings: 5,
      );
      expect(result.scoring.level, RiskLevel.medium);
      expect(
        result.scoring.totalScore,
        lessThanOrEqualTo(
          defaultRiskScoringPolicy.maxSupportingOnlyMediumScore,
        ),
      );
      expect(result.scoring.level, isNot(RiskLevel.high));
    });

    test('randomised address prefix is ignored', () {
      final engine = DetectionEngine(matcher: _testMatcher);
      final session = ScanSession();
      session.observe(
        DetectedSignal(
          id: 'F2:0B:9A:12:34:56',
          seenAt: DateTime(2025, 1, 1),
        ),
      );
      final assessment =
          engine.assessAll(session.activeSignals(DateTime(2025, 1, 1))).single;
      expect(assessment.contributesToRisk, isFalse);
    });

    test('known name drives score; address prefix supports within cap', () {
      final result = _evaluate(
        DetectedSignal(
          id: '00:0B:9A:12:34:56',
          displayName: 'Ray-Ban Meta',
          seenAt: DateTime(2025, 1, 1),
          rssi: -85,
        ),
      );
      expect(result.scoring.level, RiskLevel.medium);
      expect(result.scoring.totalScore, greaterThanOrEqualTo(15));
      expect(result.scoring.totalScore, lessThan(40));
    });

    test('known name with modifiers can reach high', () {
      final result = _evaluate(
        DetectedSignal(
          id: '11:22:33:44:55:66',
          displayName: 'Ray-Ban Meta',
          seenAt: DateTime(2025, 1, 1),
          rssi: -45,
          isConnectable: true,
        ),
        sightings: 4,
      );
      expect(result.scoring.level, RiskLevel.high);
      expect(result.scoring.totalScore, greaterThanOrEqualTo(40));
    });
  });

  group('cross-signature isolation', () {
    test('name from A plus UUID from B does not add B evidence or over-boost',
        () {
      final engine = DetectionEngine(matcher: _testMatcher);
      final session = ScanSession();
      session.observe(
        DetectedSignal(
          id: 'aa:bb:cc:dd:ee:ff',
          displayName: 'Ray-Ban Meta',
          serviceIds: ['0000bbbb-0000-1000-8000-00805f9b34fb'],
          seenAt: DateTime(2025, 1, 1),
          rssi: -70,
        ),
      );
      final assessment =
          engine.assessAll(session.activeSignals(DateTime(2025, 1, 1))).single;

      expect(assessment.matchedSignature?.id, 'test-brand-a');
      expect(
        assessment.evidence.any(
          (e) => e.kind == DetectionEvidenceKind.serviceUuidHint,
        ),
        isFalse,
      );
      expect(
        assessment.evidence.any((e) => e.label.contains('Test Brand B')),
        isFalse,
      );

      final score = RiskScoringEngine().evaluate(
        DetectionSnapshot(
          assessments: [assessment],
          capturedAt: DateTime(2025, 1, 1),
        ),
      );
      expect(score.totalScore, 35);
    });

    test('name from A plus manufacturer from B does not over-boost', () {
      final crossSig = DetectionEngine(matcher: _testMatcher).assessAll([
        makeTrackedSignal(
          id: 'aa:bb:cc:dd:ee:ff',
          name: 'Ray-Ban Meta',
          manufacturerIds: [0x00B2],
          rssi: -70,
        ),
      ]).single;
      final sameSig = DetectionEngine(matcher: _testMatcher).assessAll([
        makeTrackedSignal(
          id: 'aa:bb:cc:dd:ee:ff',
          name: 'Ray-Ban Meta',
          manufacturerIds: [0x00A1],
          rssi: -70,
        ),
      ]).single;

      expect(
        crossSig.evidence.any(
          (e) => e.kind == DetectionEvidenceKind.manufacturerIdHint,
        ),
        isFalse,
      );
      expect(
        sameSig.evidence.any(
          (e) => e.kind == DetectionEvidenceKind.manufacturerIdHint,
        ),
        isTrue,
      );

      final crossScore = RiskScoringEngine().evaluate(
        DetectionSnapshot(
          assessments: [crossSig],
          capturedAt: DateTime(2025, 1, 1),
        ),
      );
      final sameScore = RiskScoringEngine().evaluate(
        DetectionSnapshot(
          assessments: [sameSig],
          capturedAt: DateTime(2025, 1, 1),
        ),
      );
      expect(crossScore.totalScore, 35);
      expect(
        sameScore.totalScore,
        crossScore.totalScore +
            defaultRiskScoringPolicy.sameSignatureSupportBonus,
      );
    });
  });

  group('benign devices and copy guardrails', () {
    test('benign headphone with manufacturer ID stays low', () {
      final result = _evaluate(
        DetectedSignal(
          id: 'aa:bb:cc:dd:ee:ff',
          displayName: 'JBL Flip 6',
          manufacturerIds: [0xFFFF],
          seenAt: DateTime(2025, 1, 1),
          rssi: -35,
        ),
      );
      expect(result.scoring.level, RiskLevel.low);
    });

    test('scoring reasons avoid certainty language', () {
      final result = _evaluate(
        DetectedSignal(
          id: '00:0B:9A:12:34:56',
          displayName: 'Ray-Ban Meta',
          serviceIds: ['0000aaaa-0000-1000-8000-00805f9b34fb'],
          manufacturerIds: [0x00A1],
          seenAt: DateTime(2025, 1, 1),
          rssi: -42,
          isConnectable: true,
        ),
      );
      for (final reason in result.scoring.reasons) {
        expectNoCertaintyLanguage(reason);
      }
    });
  });
}
