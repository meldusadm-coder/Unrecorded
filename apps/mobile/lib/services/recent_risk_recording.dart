import 'package:unrecorded_core/unrecorded_core.dart';

import 'recent_risk_prefs.dart';

/// Records a recent-risk event from the background foreground-task isolate.
Future<void> recordRecentRiskFromBackground({
  required RiskLevel riskLevel,
  required List<DetectionAssessment> assessments,
  DateTime Function()? now,
}) async {
  final prefs = await RecentRiskPrefs.load();
  if (prefs.window == RecentRiskWindow.off) return;

  final event = RecentRiskEvent(
    noticedAt: (now ?? DateTime.now)(),
    riskLevel: riskLevel,
    reasons: recentRiskReasonsForAssessments(assessments),
    acknowledged: false,
  );
  await prefs.setEvent(event);
}
