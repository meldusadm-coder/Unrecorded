import '../detection/detection_assessment.dart';

/// Input to [RiskScoringEngine] — fully assessed signals at one point in time.
class DetectionSnapshot {
  const DetectionSnapshot({
    required this.assessments,
    required this.capturedAt,
  });

  final List<DetectionAssessment> assessments;
  final DateTime capturedAt;

  bool get isEmpty => assessments.isEmpty;

  Iterable<DetectionAssessment> get riskContributors =>
      assessments.where((a) => a.contributesToRisk);
}
