import '../detection/detection_engine.dart';
import '../models/detected_signal.dart';
import '../session/scan_session.dart';
import 'detection_snapshot.dart';
import 'risk_scoring_engine.dart';

/// Result of one pipeline tick (session → assess → score).
class PipelineResult {
  const PipelineResult({
    required this.snapshot,
    required this.scoring,
  });

  final DetectionSnapshot snapshot;
  final ScoringResult scoring;
}

/// batch → session → detection → scoring (pure Dart).
class DetectionPipeline {
  DetectionPipeline({
    ScanSession? session,
    DetectionEngine? detectionEngine,
    RiskScoringEngine? scoringEngine,
  })  : session = session ?? ScanSession(),
        _detectionEngine = detectionEngine ?? DetectionEngine(),
        _scoringEngine = scoringEngine ?? RiskScoringEngine();

  final ScanSession session;
  final DetectionEngine _detectionEngine;
  final RiskScoringEngine _scoringEngine;

  PipelineResult processBatch(
    List<DetectedSignal> batch,
    DateTime now,
  ) {
    session.observeAll(batch);
    session.expireStale(now);
    return _evaluateActive(now);
  }

  PipelineResult expireAndEvaluate(DateTime now) {
    session.expireStale(now);
    return _evaluateActive(now);
  }

  PipelineResult _evaluateActive(DateTime now) {
    final active = session.activeSignals(now);
    final assessments = _detectionEngine.assessAll(active);
    final snapshot = DetectionSnapshot(
      assessments: assessments,
      capturedAt: now,
    );
    final scoring = _scoringEngine.evaluate(snapshot);
    return PipelineResult(snapshot: snapshot, scoring: scoring);
  }

  void reset() => session.reset();
}
