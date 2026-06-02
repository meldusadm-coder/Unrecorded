import 'package:test/test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';

void main() {
  group('RiskScoringPolicy', () {
    test('levelFromScore respects medium/high edges', () {
      const policy = RiskScoringPolicy();
      expect(policy.levelFromScore(14), RiskLevel.low);
      expect(policy.levelFromScore(15), RiskLevel.medium);
      expect(policy.levelFromScore(39), RiskLevel.medium);
      expect(policy.levelFromScore(40), RiskLevel.high);
    });

    test('custom thresholds are honored', () {
      const policy = RiskScoringPolicy(mediumThreshold: 20, highThreshold: 50);
      expect(policy.levelFromScore(19), RiskLevel.low);
      expect(policy.levelFromScore(20), RiskLevel.medium);
      expect(policy.levelFromScore(49), RiskLevel.medium);
      expect(policy.levelFromScore(50), RiskLevel.high);
    });
  });
}
