/// Pure Dart core library for Unrecorded.
///
/// Provides models, deterministic risk scoring, and privacy utilities.
/// No Flutter dependency — this package is testable with plain `dart test`.
library;

export 'src/classification/device_signal_category.dart';
export 'src/classification/device_signal_classifier.dart';
export 'src/detection/benign_name_matcher.dart';
export 'src/detection/confidence_band.dart';
export 'src/detection/detection_assessment.dart';
export 'src/detection/detection_engine.dart';
export 'src/detection/detection_evidence.dart';
export 'src/detection/detection_signature.dart';
export 'src/detection/detection_signatures.dart';
export 'src/detection/signature_matcher.dart';
export 'src/models/detected_signal.dart';
export 'src/models/risk_level.dart';
export 'src/session/scan_session.dart';
export 'src/session/signal_observation.dart';
export 'src/session/signal_stable_key.dart';
export 'src/session/tracked_signal.dart';
export 'src/scoring/detection_pipeline.dart';
export 'src/scoring/detection_snapshot.dart';
export 'src/scoring/risk_scoring_engine.dart';
export 'src/scoring/risk_scoring_policy.dart';
export 'src/privacy/privacy_disclaimer.dart';
export 'src/copy/app_copy.dart';
