import '../models/risk_level.dart';

/// Thresholds and caps for deterministic risk scoring.
class RiskScoringPolicy {
  const RiskScoringPolicy({
    this.mediumThreshold = 15,
    this.highThreshold = 40,
    this.maxSupportingOnlyMediumScore = 29,
    this.supportingBaseWeight = 20,
    this.sameSignatureSupportBonus = 3,
    this.repeatBoostTwoToThree = 5,
    this.repeatBoostFourPlus = 8,
    this.strongRssiThreshold = -55,
    this.moderateRssiThreshold = -68,
    this.strongRssiPoints = 10,
    this.moderateRssiPoints = 5,
    this.connectablePoints = 10,
  }) : assert(maxSupportingOnlyMediumScore < highThreshold);

  final int mediumThreshold;
  final int highThreshold;

  /// Supporting-only matches (no name) cannot exceed this score — clearly
  /// medium-at-most, well below [highThreshold].
  final int maxSupportingOnlyMediumScore;

  /// Base score for standalone service-UUID or manufacturer-ID matches.
  final int supportingBaseWeight;

  /// Small bonus when same-signature UUID/manufacturer/address supports a name.
  final int sameSignatureSupportBonus;

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
