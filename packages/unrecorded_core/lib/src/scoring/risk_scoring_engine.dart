import '../detection/detection_assessment.dart';
import '../detection/detection_evidence.dart';
import '../detection/signature_matcher.dart' show SignatureMatchKind;
import '../models/detected_signal.dart';
import '../models/risk_level.dart';
import 'detection_snapshot.dart';
import 'risk_scoring_policy.dart';

/// Result of scoring a [DetectionSnapshot].
class ScoringResult {
  final RiskLevel level;
  final int totalScore;
  final List<String> reasons;
  final List<DetectionAssessment> contributingAssessments;

  const ScoringResult({
    required this.level,
    required this.totalScore,
    required this.reasons,
    this.contributingAssessments = const [],
  });
}

/// Scores [DetectionAssessment] objects only — no matching or classification.
class RiskScoringEngine {
  RiskScoringEngine({RiskScoringPolicy? policy})
      : _policy = policy ?? defaultRiskScoringPolicy;

  final RiskScoringPolicy _policy;

  ScoringResult evaluate(DetectionSnapshot snapshot) {
    if (snapshot.isEmpty) {
      return const ScoringResult(
        level: RiskLevel.low,
        totalScore: 0,
        reasons: ['No nearby signals detected.'],
      );
    }

    var bestScore = 0;
    final reasons = <String>{};
    final contributing = <DetectionAssessment>[];

    for (final assessment in snapshot.assessments) {
      if (!assessment.contributesToRisk) continue;

      final signalScore = _scoreAssessment(assessment);
      if (signalScore <= 0) continue;

      contributing.add(assessment);
      final signalReasons = _reasonsFor(assessment, signalScore);

      if (signalScore > bestScore) {
        bestScore = signalScore;
        reasons
          ..clear()
          ..addAll(signalReasons);
      }
    }

    final level = _policy.levelFromScore(bestScore);

    if (reasons.isEmpty && snapshot.assessments.isNotEmpty) {
      reasons.add(
        'Nearby signals were detected but none match known '
        'recording-device patterns.',
      );
    }

    return ScoringResult(
      level: level,
      totalScore: bestScore,
      reasons: reasons.toList(),
      contributingAssessments: contributing,
    );
  }

  int _scoreAssessment(DetectionAssessment assessment) {
    final signature = assessment.matchedSignature;
    final hasAddressOnly = signature == null &&
        assessment.evidence.any(
          (e) => e.kind == DetectionEvidenceKind.addressPrefixHint,
        );
    if (signature == null && !hasAddressOnly) return 0;

    var score = 0;
    final kind = assessment.primaryMatchKind;

    if (signature != null) {
      score += switch (kind) {
        SignatureMatchKind.name ||
        SignatureMatchKind.serviceUuid =>
          signature.confidenceWeight,
        SignatureMatchKind.macPrefix => signature.confidenceWeight >= 5
            ? signature.confidenceWeight - 5
            : signature.confidenceWeight,
        null => signature.confidenceWeight,
      };
    } else {
      score += 20;
    }

    final rssi =
        assessment.signal.smoothedRssi?.round() ?? assessment.signal.lastRssi;
    if (rssi != null && signature != null) {
      if (rssi >= _policy.strongRssiThreshold) {
        score += _policy.strongRssiPoints;
      } else if (rssi >= _policy.moderateRssiThreshold) {
        score += _policy.moderateRssiPoints;
      }
    }

    if (assessment.signal.everConnectable && signature != null) {
      score += _policy.connectablePoints;
    }

    final sightings = assessment.signal.sightingCount;
    if (signature != null) {
      if (sightings >= 4) {
        score += _policy.repeatBoostFourPlus;
      } else if (sightings >= 2) {
        score += _policy.repeatBoostTwoToThree;
      }
    }

    final macOnly = kind == SignatureMatchKind.macPrefix &&
        !assessment.evidence.any(
          (e) =>
              e.kind == DetectionEvidenceKind.nameMatch ||
              e.kind == DetectionEvidenceKind.serviceUuidHint,
        );

    if (macOnly && score > _policy.macOnlyMaxScore) {
      score = _policy.macOnlyMaxScore;
    }

    return score;
  }

  List<String> _reasonsFor(DetectionAssessment assessment, int score) {
    final reasons = <String>[];
    for (final e in assessment.evidence) {
      if (e.kind == DetectionEvidenceKind.benignName ||
          e.kind == DetectionEvidenceKind.unknown) {
        continue;
      }
      reasons.add(e.label);
    }
    if (score > 0 && reasons.isEmpty && assessment.matchedSignature != null) {
      reasons.add(assessment.matchedSignature!.matchExplanation);
    }
    return reasons;
  }
}

// Keep contributing DetectedSignal access for migration adapters.
extension ScoringResultSignals on ScoringResult {
  List<DetectedSignal> get contributingSignals =>
      contributingAssessments.map((a) => a.signal.toDetectedSignal()).toList();
}
