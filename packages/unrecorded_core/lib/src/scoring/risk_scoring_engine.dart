import '../models/risk_level.dart';
import '../models/scan_snapshot.dart';
import 'scoring_rule.dart';
import 'default_scoring_rules.dart';

/// Result of scoring a [ScanSnapshot].
class ScoringResult {
  /// The overall risk level.
  final RiskLevel level;

  /// Numeric score (higher = more risk indicators found).
  final int totalScore;

  /// Plain-English reasons explaining why this risk level was assigned.
  final List<String> reasons;

  const ScoringResult({
    required this.level,
    required this.totalScore,
    required this.reasons,
  });
}

/// Deterministic, rule-based scoring engine.
///
/// Evaluates each signal in a snapshot against a set of [ScoringRule]s
/// and produces a [ScoringResult] with a risk level, score, and
/// human-readable reasons.
class RiskScoringEngine {
  final List<ScoringRule> _rules;

  /// Creates an engine with default rules unless custom [rules] are supplied.
  RiskScoringEngine({List<ScoringRule>? rules})
    : _rules =
          rules ??
          [SuspiciousNameRule(), StrongSignalRule(), ConnectableDeviceRule()];

  /// Score a single [ScanSnapshot] and return a [ScoringResult].
  ScoringResult evaluate(ScanSnapshot snapshot) {
    if (snapshot.isEmpty) {
      return const ScoringResult(
        level: RiskLevel.low,
        totalScore: 0,
        reasons: ['No nearby signals detected.'],
      );
    }

    var total = 0;
    final reasons = <String>{};

    for (final signal in snapshot.signals) {
      for (final rule in _rules) {
        final pts = rule.score(signal);
        if (pts > 0) {
          total += pts;
          final r = rule.reason(signal);
          if (r != null) reasons.add(r);
        }
      }
    }

    final level = _levelFromScore(total);

    if (reasons.isEmpty) {
      reasons.add(
        'Nearby signals were detected but none match known '
        'recording-device patterns.',
      );
    }

    return ScoringResult(
      level: level,
      totalScore: total,
      reasons: reasons.toList(),
    );
  }

  static RiskLevel _levelFromScore(int score) {
    if (score >= 40) return RiskLevel.high;
    if (score >= 15) return RiskLevel.medium;
    return RiskLevel.low;
  }
}
