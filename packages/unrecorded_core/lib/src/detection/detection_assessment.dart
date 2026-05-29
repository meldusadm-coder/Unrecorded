import '../classification/device_signal_category.dart';
import '../session/tracked_signal.dart';
import 'confidence_band.dart';
import 'detection_evidence.dart';
import 'detection_signature.dart';
import 'signature_matcher.dart';

/// Assessment of one tracked signal (matching + evidence, no score).
class DetectionAssessment {
  const DetectionAssessment({
    required this.signal,
    required this.category,
    this.matchedSignature,
    required this.evidence,
    required this.confidenceBand,
    required this.contributesToRisk,
    this.primaryMatchKind,
  });

  final TrackedSignal signal;
  final DeviceSignalCategory category;
  final DetectionSignature? matchedSignature;
  final List<DetectionEvidence> evidence;
  final ConfidenceBand confidenceBand;
  final bool contributesToRisk;

  /// Strongest catalogue match kind when present.
  final SignatureMatchKind? primaryMatchKind;
}
