/// Pure Dart core library for Unrecorded.
///
/// Provides models, deterministic risk scoring, and privacy utilities.
/// No Flutter dependency — this package is testable with plain `dart test`.
library;

export 'src/models/detected_signal.dart';
export 'src/models/risk_level.dart';
export 'src/models/scan_snapshot.dart';
export 'src/scoring/risk_scoring_engine.dart';
export 'src/scoring/scoring_rule.dart';
export 'src/scoring/default_scoring_rules.dart';
export 'src/privacy/privacy_disclaimer.dart';
