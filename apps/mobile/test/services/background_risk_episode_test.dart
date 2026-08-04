import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_mobile/services/background_risk_episode.dart';

DetectionAssessment _riskAssessment({
  required String key,
  DeviceSignalCategory category =
      DeviceSignalCategory.possibleRecordingWearable,
}) {
  return DetectionAssessment(
    signal: TrackedSignal(
      stableKey: key,
      id: key,
      firstSeenAt: DateTime.utc(2026, 1, 1),
      lastSeenAt: DateTime.utc(2026, 1, 1, 0, 0, 1),
      lastRssi: -60,
      sightingCount: 2,
      displayName: null,
    ),
    category: category,
    evidence: const [
      DetectionEvidence(
        kind: DetectionEvidenceKind.nameMatch,
        label: 'name',
      ),
    ],
    confidenceBand: ConfidenceBand.elevated,
    contributesToRisk: true,
  );
}

void main() {
  test('opens opaque episode ids and keeps fingerprint task-local', () {
    final tracker = BackgroundRiskEpisodeTracker();
    final episode = tracker.update(
      assessments: [_riskAssessment(key: 'a')],
      riskLevel: RiskLevel.high,
      isLiveRisk: true,
    );

    expect(episode, isNotNull);
    expect(episode!.riskEpisodeId, 'ep-1');
    expect(episode.fingerprint, contains('a'));
    expect(episode.riskLevelName, RiskLevel.high.name);
  });

  test('same fingerprint reuses episode; material change opens new id', () {
    final tracker = BackgroundRiskEpisodeTracker();
    final first = tracker.update(
      assessments: [_riskAssessment(key: 'a')],
      riskLevel: RiskLevel.medium,
      isLiveRisk: true,
    );
    final same = tracker.update(
      assessments: [_riskAssessment(key: 'a')],
      riskLevel: RiskLevel.high,
      isLiveRisk: true,
    );
    expect(same!.riskEpisodeId, first!.riskEpisodeId);
    expect(same.riskLevelName, RiskLevel.high.name);

    final next = tracker.update(
      assessments: [
        _riskAssessment(key: 'a'),
        _riskAssessment(key: 'b'),
      ],
      riskLevel: RiskLevel.high,
      isLiveRisk: true,
    );
    expect(next!.riskEpisodeId, 'ep-2');
    expect(next.riskEpisodeId, isNot(first.riskEpisodeId));
  });

  test('clearing live risk closes episode', () {
    final tracker = BackgroundRiskEpisodeTracker();
    tracker.update(
      assessments: [_riskAssessment(key: 'a')],
      riskLevel: RiskLevel.high,
      isLiveRisk: true,
    );
    final cleared = tracker.update(
      assessments: const [],
      riskLevel: RiskLevel.low,
      isLiveRisk: false,
    );
    expect(cleared, isNull);
    expect(tracker.current, isNull);
  });

  test('fingerprint ignores non-contributing assessments', () {
    final risk = _riskAssessment(key: 'risk');
    final other = DetectionAssessment(
      signal: TrackedSignal(
        stableKey: 'other',
        id: 'other',
        firstSeenAt: DateTime.utc(2026, 1, 1),
        lastSeenAt: DateTime.utc(2026, 1, 1),
        lastRssi: -70,
        sightingCount: 1,
        displayName: null,
      ),
      category: DeviceSignalCategory.likelyAudio,
      evidence: const [],
      confidenceBand: ConfidenceBand.low,
      contributesToRisk: false,
    );
    final fp = backgroundRiskFingerprint([risk, other]);
    expect(fp, contains('risk'));
    expect(fp, isNot(contains('other')));
  });
}
