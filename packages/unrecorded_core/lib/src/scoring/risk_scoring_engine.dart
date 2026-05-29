import '../detection/signature_matcher.dart';
import '../models/detected_signal.dart';
import '../models/risk_level.dart';
import '../models/scan_snapshot.dart';
import 'default_scoring_rules.dart';
import 'scoring_rule.dart';

/// Result of scoring a [ScanSnapshot].
class ScoringResult {
  /// The overall risk level.
  final RiskLevel level;

  /// Numeric score (higher = more risk indicators found).
  final int totalScore;

  /// Plain-English reasons explaining why this risk level was assigned.
  final List<String> reasons;

  /// Signals that contributed at least one scoring rule (for alert details).
  final List<DetectedSignal> contributingSignals;

  const ScoringResult({
    required this.level,
    required this.totalScore,
    required this.reasons,
    this.contributingSignals = const [],
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
  RiskScoringEngine({List<ScoringRule>? rules, SignatureMatcher? matcher})
      : _rules = rules ?? _defaultRules(matcher ?? const SignatureMatcher());

  static List<ScoringRule> _defaultRules(SignatureMatcher matcher) => [
        SignatureMatchRule(matcher: matcher),
        StrongSignalRule(matcher: matcher),
        ConnectableDeviceRule(matcher: matcher),
      ];

  List<ScoringRule> get rules => List.unmodifiable(_rules);

  /// Score a single [ScanSnapshot] and return a [ScoringResult].
  ScoringResult evaluate(ScanSnapshot snapshot) {
    if (snapshot.isEmpty) {
      return const ScoringResult(
        level: RiskLevel.low,
        totalScore: 0,
        reasons: ['No nearby signals detected.'],
      );
    }

    var bestScore = 0;
    final reasons = <String>{};
    final contributing = <DetectedSignal>[];

    for (final signal in snapshot.signals) {
      var signalScore = 0;
      final signalReasons = <String>{};
      for (final rule in _rules) {
        final pts = rule.score(signal);
        if (pts > 0) {
          signalScore += pts;
          final r = rule.reason(signal);
          if (r != null) signalReasons.add(r);
        }
      }
      if (signalScore > 0) contributing.add(signal);
      if (signalScore > bestScore) {
        bestScore = signalScore;
        reasons
          ..clear()
          ..addAll(signalReasons);
      }
    }

    final level = _levelFromScore(bestScore);

    if (reasons.isEmpty) {
      reasons.add(
        'Nearby signals were detected but none match known '
        'recording-device patterns.',
      );
    }

    return ScoringResult(
      level: level,
      totalScore: bestScore,
      reasons: reasons.toList(),
      contributingSignals: contributing,
    );
  }

  static RiskLevel _levelFromScore(int score) {
    if (score >= 40) return RiskLevel.high;
    if (score >= 15) return RiskLevel.medium;
    return RiskLevel.low;
  }
}
