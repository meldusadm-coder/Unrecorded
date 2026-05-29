import '../models/risk_level.dart';

/// Thresholds and caps for deterministic risk scoring.
class RiskScoringPolicy {
  const RiskScoringPolicy({
    this.mediumThreshold = 15,
    this.highThreshold = 40,
    this.macOnlyMaxScore = 39,
    this.repeatBoostTwoToThree = 5,
    this.repeatBoostFourPlus = 8,
    this.strongRssiThreshold = -55,
    this.moderateRssiThreshold = -68,
    this.strongRssiPoints = 10,
    this.moderateRssiPoints = 5,
    this.connectablePoints = 10,
  });

  final int mediumThreshold;
  final int highThreshold;

  /// MAC-prefix-only matches cannot exceed this score (stays below high).
  final int macOnlyMaxScore;

  final int repeatBoostTwoToThree;
  final int repeatBoostFourPlus;

  final int strongRssiThreshold;
  final int moderateRssiThreshold;
  final int strongRssiPoints;
  final int moderateRssiPoints;
  final int connectablePoints;

  RiskLevel levelFromScore(int score) {
    if (score >= highThreshold) return RiskLevel.high;
    if (score >= mediumThreshold) return RiskLevel.medium;
    return RiskLevel.low;
  }
}

const defaultRiskScoringPolicy = RiskScoringPolicy();
