import '../models/detected_signal.dart';

/// A single scoring rule that can contribute points and a human-readable
/// reason when a signal matches.
abstract class ScoringRule {
  /// Evaluate [signal] and return a score contribution (0 = no match).
  int score(DetectedSignal signal);

  /// A plain-English reason shown to the user when this rule fires.
  /// Returns `null` if the rule did not match.
  String? reason(DetectedSignal signal);
}
