import 'package:test/test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';

import 'support/certainty_language.dart';

PipelineResult _evaluate(List<DetectedSignal> signals, {ScanSession? session}) {
  final pipeline = DetectionPipeline(session: session);
  final base = DateTime(2025, 6, 1, 12, 0, 0);
  for (var i = 0; i < signals.length; i++) {
    final seenAt = base.add(Duration(seconds: i));
    final signal = DetectedSignal(
      id: signals[i].id,
      displayName: signals[i].displayName,
      rssi: signals[i].rssi,
      serviceIds: signals[i].serviceIds,
      seenAt: seenAt,
      isConnectable: signals[i].isConnectable,
    );
    pipeline.processBatch([signal], seenAt);
  }
  final end = base.add(Duration(seconds: signals.length));
  return pipeline.expireAndEvaluate(end);
}

PipelineResult _evaluateRepeated(
  DetectedSignal signal, {
  int sightings = 2,
}) {
  final pipeline = DetectionPipeline();
  final base = DateTime(2025, 6, 1, 12, 0, 0);
  for (var i = 0; i < sightings; i++) {
    final seenAt = base.add(Duration(seconds: i * 3));
    pipeline.processBatch(
      [
        DetectedSignal(
          id: signal.id,
          displayName: signal.displayName,
          rssi: signal.rssi,
          seenAt: seenAt,
          isConnectable: signal.isConnectable,
          serviceIds: signal.serviceIds,
        ),
      ],
      seenAt,
    );
  }
  return pipeline.expireAndEvaluate(base.add(Duration(seconds: sightings * 3)));
}

class _ScoreCase {
  _ScoreCase({
    required this.description,
    required this.signal,
    required this.expectedLevel,
    this.minScore,
    this.maxScore,
  });

  final String description;
  final DetectedSignal signal;
  final RiskLevel expectedLevel;
  final int? minScore;
  final int? maxScore;
}

void main() {
  group('RiskScoringEngine via DetectionPipeline', () {
    test('empty scan returns low risk', () {
      final pipeline = DetectionPipeline();
      final result = pipeline.expireAndEvaluate(DateTime(2025, 1, 1));
      expect(result.scoring.level, RiskLevel.low);
      expect(result.scoring.totalScore, 0);
    });

    test('harmless unknown signal returns low risk', () {
      final result = _evaluate([
        DetectedSignal(
          id: 'aa:bb:cc:dd:ee:ff',
          displayName: 'JBL Flip 6',
          rssi: -75,
          seenAt: DateTime(2025, 6, 1),
        ),
      ]);
      expect(result.scoring.level, RiskLevel.low);
      expect(result.scoring.totalScore, 0);
    });

    test('single suspicious device reaches high with strong modifiers', () {
      final result = _evaluateRepeated(
        DetectedSignal(
          id: '11:22:33:44:55:66',
          displayName: 'Ray-Ban Meta',
          rssi: -45,
          seenAt: DateTime(2025, 6, 1),
          isConnectable: true,
        ),
        sightings: 4,
      );
      expect(result.scoring.level, RiskLevel.high);
      expect(result.scoring.totalScore, greaterThanOrEqualTo(40));
    });

    test('repeated unknown strong signal stays low', () {
      final result = _evaluateRepeated(
        DetectedSignal(
          id: 'de:ad:be:ef:00:01',
          displayName: 'Mystery Device',
          rssi: -40,
          seenAt: DateTime(2025, 6, 1),
        ),
        sightings: 5,
      );
      expect(result.scoring.level, RiskLevel.low);
    });

    test('generic glasses name remains bounded without stronger indicators',
        () {
      final result = _evaluate([
        DetectedSignal(
          id: 'aa:bb:cc:dd:ee:ff',
          displayName: 'My Smart Glasses',
          rssi: -85,
          seenAt: DateTime(2025, 6, 1),
        ),
      ]);
      expect(result.scoring.level, RiskLevel.medium);
      expect(result.scoring.totalScore, lessThan(40));
    });

    test('table-driven positives stay medium/high and negatives stay low', () {
      final positives = <String>[
        'Ray-Ban',
        'Ray-Ban Meta',
        'Meta Smart Glasses',
        'Spectacles',
        'Snap glasses',
        'Even Realities',
        'Focals',
        'Vuzix',
        'Xreal Air',
        'Nreal',
        'Inmo',
        'TCL RayNeo',
        'Solos',
        'smart glasses',
        'wearable camera',
        'camera glasses',
      ];
      final negatives = <String?>[
        'JBL Flip',
        'AirPods',
        'Galaxy Buds',
        'headphones',
        'Bluetooth speaker',
        'keyboard',
        'mouse',
        'watch',
        'fitness tracker',
        'TV',
        'car Bluetooth',
        '550e8400-e29b-41d4-a716-446655440000',
        null,
      ];

      final cases = <_ScoreCase>[
        for (var i = 0; i < positives.length; i++)
          _ScoreCase(
            description: 'positive:${positives[i]}',
            signal: DetectedSignal(
              id: 'p$i',
              displayName: positives[i],
              rssi: -72,
              seenAt: DateTime(2025, 1, 1),
            ),
            expectedLevel: RiskLevel.medium,
            minScore: 15,
            maxScore: positives[i] == 'smart glasses' ||
                    positives[i] == 'wearable camera'
                ? 39
                : null,
          ),
        for (var i = 0; i < negatives.length; i++)
          _ScoreCase(
            description: 'negative:${negatives[i]}',
            signal: DetectedSignal(
              id: i == negatives.length - 1 ? '12:34:56:78:9A:BC' : 'n$i',
              displayName: negatives[i],
              rssi: -35,
              seenAt: DateTime(2025, 1, 1),
            ),
            expectedLevel: RiskLevel.low,
            maxScore: 0,
          ),
      ];

      for (final c in cases) {
        final result = _evaluate([c.signal]);
        expect(result.scoring.level, c.expectedLevel, reason: c.description);
        if (c.minScore != null) {
          expect(
            result.scoring.totalScore,
            greaterThanOrEqualTo(c.minScore!),
            reason: c.description,
          );
        }
        if (c.maxScore != null) {
          expect(
            result.scoring.totalScore,
            lessThanOrEqualTo(c.maxScore!),
            reason: c.description,
          );
        }
      }
    });

    test('mac-only prefix hint can reach medium but not high', () {
      final result = _evaluate([
        DetectedSignal(
          id: '00:0B:9A:12:34:56',
          rssi: -70,
          seenAt: DateTime(2025, 6, 1),
        ),
      ]);
      expect(result.scoring.level, RiskLevel.medium);
      expect(result.scoring.totalScore, lessThan(40));
    });

    test('deterministic scoring for identical input', () {
      final input = [
        DetectedSignal(
          id: 'same-id',
          displayName: 'Ray-Ban Meta',
          rssi: -52,
          isConnectable: true,
          seenAt: DateTime(2025, 6, 1),
        ),
      ];
      final first = _evaluate(input);
      final second = _evaluate(input);
      expect(second.scoring.level, first.scoring.level);
      expect(second.scoring.totalScore, first.scoring.totalScore);
      expect(second.scoring.reasons, first.scoring.reasons);
    });

    test('stale signals expire to low risk', () {
      final session = ScanSession(staleTtl: const Duration(seconds: 2));
      final pipeline = DetectionPipeline(session: session);
      final t0 = DateTime(2025, 6, 1, 12, 0, 0);
      pipeline.processBatch(
        [
          DetectedSignal(
            id: '1',
            displayName: 'Ray-Ban Meta',
            rssi: -40,
            seenAt: t0,
            isConnectable: true,
          ),
        ],
        t0,
      );
      final staleEval =
          pipeline.expireAndEvaluate(t0.add(const Duration(seconds: 3)));
      expect(staleEval.scoring.level, RiskLevel.low);
      expect(staleEval.snapshot.assessments, isEmpty);
    });

    test('pipeline reset clears prior risky history', () {
      final pipeline = DetectionPipeline();
      final t0 = DateTime(2025, 6, 1, 12, 0, 0);
      pipeline.processBatch(
        [
          DetectedSignal(
            id: '1',
            displayName: 'Ray-Ban Meta',
            rssi: -40,
            seenAt: t0,
            isConnectable: true,
          ),
        ],
        t0,
      );
      pipeline.reset();
      final result =
          pipeline.expireAndEvaluate(t0.add(const Duration(seconds: 1)));
      expect(result.scoring.level, RiskLevel.low);
      expect(result.scoring.totalScore, 0);
    });

    test('scoring reasons avoid certainty language', () {
      final result = _evaluate([
        DetectedSignal(
          id: '1',
          displayName: 'Ray-Ban Meta',
          rssi: -42,
          seenAt: DateTime(2025, 6, 1),
          isConnectable: true,
        ),
      ]);
      for (final reason in result.scoring.reasons) {
        expectNoCertaintyLanguage(reason);
      }
    });
  });
}
