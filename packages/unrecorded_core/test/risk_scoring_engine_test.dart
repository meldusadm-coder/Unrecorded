import 'package:test/test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';

void main() {
  late RiskScoringEngine engine;

  setUp(() {
    engine = RiskScoringEngine();
  });

  group('RiskScoringEngine', () {
    test('empty scan returns low risk', () {
      final snapshot = ScanSnapshot(signals: [], capturedAt: DateTime.now());
      final result = engine.evaluate(snapshot);

      expect(result.level, RiskLevel.low);
      expect(result.totalScore, 0);
      expect(result.reasons, isNotEmpty);
    });

    test('harmless unknown signal returns low risk', () {
      final snapshot = ScanSnapshot(
        signals: [
          DetectedSignal(
            id: 'aa:bb:cc:dd:ee:ff',
            displayName: 'JBL Flip 6',
            rssi: -75,
            seenAt: DateTime.now(),
          ),
        ],
        capturedAt: DateTime.now(),
      );
      final result = engine.evaluate(snapshot);

      expect(result.level, RiskLevel.low);
      expect(result.totalScore, 0);
      expect(result.reasons, isNotEmpty);
    });

    test('suspicious named signal returns medium or high risk', () {
      final snapshot = ScanSnapshot(
        signals: [
          DetectedSignal(
            id: '11:22:33:44:55:66',
            displayName: 'Ray-Ban Stories',
            rssi: -70,
            seenAt: DateTime.now(),
          ),
        ],
        capturedAt: DateTime.now(),
      );
      final result = engine.evaluate(snapshot);

      expect(result.level, anyOf(RiskLevel.medium, RiskLevel.high));
      expect(result.totalScore, greaterThanOrEqualTo(15));
      expect(
        result.reasons.any(
          (r) =>
              r.toLowerCase().contains('smart glasses') ||
              r.toLowerCase().contains('recording'),
        ),
        isTrue,
      );
    });

    test('strong repeated suspicious signal increases risk', () {
      final snapshot = ScanSnapshot(
        signals: [
          DetectedSignal(
            id: '11:22:33:44:55:66',
            displayName: 'Meta Smart Glasses',
            rssi: -30,
            seenAt: DateTime.now(),
            isConnectable: true,
          ),
        ],
        capturedAt: DateTime.now(),
      );
      final result = engine.evaluate(snapshot);

      expect(result.level, RiskLevel.high);
      expect(result.totalScore, greaterThanOrEqualTo(40));
    });

    test('suspicious name with weak signal is less urgent', () {
      final snapshot = ScanSnapshot(
        signals: [
          DetectedSignal(
            id: '11:22:33:44:55:66',
            displayName: 'Meta Smart Glasses',
            rssi: -85,
            seenAt: DateTime.now(),
          ),
        ],
        capturedAt: DateTime.now(),
      );
      final result = engine.evaluate(snapshot);
      expect(result.level, RiskLevel.medium);
    });

    test('strong unknown signal alone does not auto-escalate to high', () {
      final snapshot = ScanSnapshot(
        signals: [
          DetectedSignal(
            id: 'de:ad:be:ef:00:01',
            displayName: 'Bluetooth Speaker',
            rssi: -45,
            seenAt: DateTime.now(),
          ),
        ],
        capturedAt: DateTime.now(),
      );
      final result = engine.evaluate(snapshot);
      expect(result.level, isNot(RiskLevel.high));
    });

    test('benign connectable nearby signal stays low risk', () {
      final snapshot = ScanSnapshot(
        signals: [
          DetectedSignal(
            id: 'aa:bb:cc:dd:ee:ff',
            displayName: 'AirPods Pro',
            rssi: -56,
            seenAt: DateTime.now(),
            isConnectable: true,
          ),
        ],
        capturedAt: DateTime.now(),
      );
      final result = engine.evaluate(snapshot);
      expect(result.level, RiskLevel.low);
      expect(result.totalScore, lessThan(15));
    });

    test('multiple suspicious signals compound the score', () {
      final snapshot = ScanSnapshot(
        signals: [
          DetectedSignal(
            id: '11:22:33:44:55:66',
            displayName: 'Ray-Ban Meta',
            rssi: -60,
            seenAt: DateTime.now(),
          ),
          DetectedSignal(
            id: '77:88:99:aa:bb:cc',
            displayName: 'Spectacles 3',
            rssi: -45,
            seenAt: DateTime.now(),
            isConnectable: true,
          ),
        ],
        capturedAt: DateTime.now(),
      );
      final result = engine.evaluate(snapshot);

      expect(result.level, RiskLevel.high);
      expect(result.totalScore, greaterThan(40));
    });

    test('explanations are present and non-technical', () {
      final snapshot = ScanSnapshot(
        signals: [
          DetectedSignal(
            id: '11:22:33:44:55:66',
            displayName: 'Smart Glasses X',
            rssi: -40,
            seenAt: DateTime.now(),
          ),
        ],
        capturedAt: DateTime.now(),
      );
      final result = engine.evaluate(snapshot);

      expect(result.reasons, isNotEmpty);
      for (final reason in result.reasons) {
        expect(reason, isNot(contains('dBm')));
        expect(reason, isNot(contains('RSSI')));
        expect(reason.length, greaterThan(10));
      }
    });
  });
}
