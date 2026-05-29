import 'package:test/test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';

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

    test('suspicious named signal returns medium or high risk', () {
      final result = _evaluate([
        DetectedSignal(
          id: '11:22:33:44:55:66',
          displayName: 'Ray-Ban Stories',
          rssi: -70,
          seenAt: DateTime(2025, 6, 1),
        ),
      ]);
      expect(
        result.scoring.level,
        anyOf(RiskLevel.medium, RiskLevel.high),
      );
      expect(result.scoring.totalScore, greaterThanOrEqualTo(15));
    });

    test('strong repeated suspicious signal increases risk', () {
      final result = _evaluateRepeated(
        DetectedSignal(
          id: '11:22:33:44:55:66',
          displayName: 'Meta Smart Glasses',
          rssi: -30,
          seenAt: DateTime(2025, 6, 1),
          isConnectable: true,
        ),
        sightings: 3,
      );
      expect(result.scoring.level, RiskLevel.high);
      expect(result.scoring.totalScore, greaterThanOrEqualTo(40));
    });

    test('suspicious name with weak signal is less urgent', () {
      final result = _evaluate([
        DetectedSignal(
          id: '11:22:33:44:55:66',
          displayName: 'Meta Smart Glasses',
          rssi: -85,
          seenAt: DateTime(2025, 6, 1),
        ),
      ]);
      expect(result.scoring.level, RiskLevel.medium);
    });

    test('multiple strong benign devices stay low risk', () {
      final result = _evaluate([
        DetectedSignal(
          id: 'aa:bb:cc:dd:ee:01',
          displayName: 'AirPods Pro',
          rssi: -45,
          seenAt: DateTime(2025, 6, 1),
          isConnectable: true,
        ),
        DetectedSignal(
          id: 'aa:bb:cc:dd:ee:02',
          displayName: 'Galaxy Buds',
          rssi: -48,
          seenAt: DateTime(2025, 6, 1),
          isConnectable: true,
        ),
      ]);
      expect(result.scoring.level, RiskLevel.low);
      expect(result.scoring.totalScore, 0);
    });

    test('strong unknown signal alone does not auto-escalate to high', () {
      final result = _evaluate([
        DetectedSignal(
          id: 'de:ad:be:ef:00:01',
          displayName: 'Bluetooth Speaker',
          rssi: -45,
          seenAt: DateTime(2025, 6, 1),
        ),
      ]);
      expect(result.scoring.level, isNot(RiskLevel.high));
    });

    test('single suspicious device can reach high with strong modifiers', () {
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

    test('MAC-only prefix match can reach medium but not high alone', () {
      final result = _evaluate([
        DetectedSignal(
          id: '00:0B:9A:12:34:56',
          rssi: -70,
          seenAt: DateTime(2025, 6, 1),
        ),
      ]);
      expect(result.scoring.level, isNot(RiskLevel.high));
      expect(result.scoring.totalScore, greaterThanOrEqualTo(15));
      expect(result.scoring.totalScore, lessThan(40));
    });

    test('repeated unknown signal stays low', () {
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

    test('generic glasses name stays medium without strong modifiers', () {
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
  });
}
