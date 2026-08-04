import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_mobile/features/scan/scan_state.dart';
import 'package:unrecorded_mobile/services/background_protection_snapshot.dart';

void main() {
  test('round-trips through JSON without sensitive fields', () {
    const original = BackgroundProtectionSnapshot(
      status: ScanStatus.scanning,
      riskLevel: RiskLevel.medium,
      score: 42,
      reasonLabels: ['Possible smart glasses nearby'],
      possibleRiskCount: 2,
      otherNearbyCount: 5,
      lastCheckedAt: null,
      isDemoMode: false,
      serviceRunning: true,
    );

    final json = original.toJson();
    final decoded = BackgroundProtectionSnapshot.fromJson(json);

    expect(decoded, isNotNull);
    expect(decoded!.status, ScanStatus.scanning);
    expect(decoded.riskLevel, RiskLevel.medium);
    expect(decoded.score, 42);
    expect(decoded.reasonLabels, ['Possible smart glasses nearby']);
    expect(decoded.possibleRiskCount, 2);
    expect(decoded.otherNearbyCount, 5);
    expect(decoded.serviceRunning, isTrue);

    final encoded = json.toString().toLowerCase();
    expect(encoded, isNot(contains('mac')));
    expect(encoded, isNot(contains('stablekey')));
    expect(encoded, isNot(contains('aa:bb')));
  });

  test('toScanState mirrors safe summary fields only', () {
    const snapshot = BackgroundProtectionSnapshot(
      status: ScanStatus.possibleRiskDetected,
      riskLevel: RiskLevel.high,
      score: 80,
      reasonLabels: ['Elevated risk'],
      possibleRiskCount: 1,
      otherNearbyCount: 0,
      isDemoMode: false,
      serviceRunning: true,
    );

    final state = snapshot.toScanState();
    expect(state.status, ScanStatus.possibleRiskDetected);
    expect(state.riskLevel, RiskLevel.high);
    expect(state.score, 80);
    expect(state.possibleRiskSignals, isEmpty);
    expect(state.otherNearbySignals, isEmpty);
    expect(state.protectionRequested, isTrue);
  });

  test('ownership-capable requires full session/lease identity', () {
    const incomplete = BackgroundProtectionSnapshot(
      status: ScanStatus.scanning,
      riskLevel: RiskLevel.low,
      score: 0,
      reasonLabels: [],
      possibleRiskCount: 0,
      otherNearbyCount: 0,
      isDemoMode: false,
      serviceRunning: true,
      sessionId: 'task-1',
      sessionEpoch: 1,
      engineIncarnationId: 'inc-1',
      // scannerLeaseId missing
    );
    expect(incomplete.isOwnershipCapable, isFalse);

    const complete = BackgroundProtectionSnapshot(
      status: ScanStatus.scanning,
      riskLevel: RiskLevel.low,
      score: 0,
      reasonLabels: [],
      possibleRiskCount: 0,
      otherNearbyCount: 0,
      isDemoMode: false,
      serviceRunning: true,
      sessionId: 'task-1',
      sessionEpoch: 1,
      engineIncarnationId: 'inc-1',
      scannerLeaseId: 'lease-1',
      messageSequence: 2,
      scannerPhase: BackgroundScannerPhase.scanning,
      riskEpisodeId: 'ep-1',
    );
    expect(complete.isOwnershipCapable, isTrue);

    final decoded = BackgroundProtectionSnapshot.fromJson(complete.toJson());
    expect(decoded!.sessionId, 'task-1');
    expect(decoded.scannerLeaseId, 'lease-1');
    expect(decoded.messageSequence, 2);
    expect(decoded.scannerPhase, BackgroundScannerPhase.scanning);
    expect(decoded.riskEpisodeId, 'ep-1');
  });

  test('explicit notification stop round-trips protocol fields', () {
    const original = BackgroundProtectionSnapshot(
      status: ScanStatus.paused,
      riskLevel: RiskLevel.low,
      score: 0,
      reasonLabels: [],
      possibleRiskCount: 0,
      otherNearbyCount: 0,
      isDemoMode: false,
      serviceRunning: false,
      stoppedReason: BackgroundProtectionStoppedReason.explicitNotificationStop,
      sessionId: 'task-1',
      sessionEpoch: 4,
      engineIncarnationId: 'inc-1',
      scannerLeaseId: 'lease-1',
      messageSequence: 9,
      scannerPhase: BackgroundScannerPhase.stopped,
      stopTransactionOutcome: StopTransactionOutcome.confirmed,
      stopConfirmedRevision: 12,
      scannerStopOutcome: 'stopped',
      leaseReleased: true,
    );

    final decoded = BackgroundProtectionSnapshot.fromJson(original.toJson());
    expect(
      decoded!.stoppedReason,
      BackgroundProtectionStoppedReason.explicitNotificationStop,
    );
    expect(decoded.stopTransactionOutcome, StopTransactionOutcome.confirmed);
    expect(decoded.stopConfirmedRevision, 12);
    expect(decoded.scannerStopOutcome, 'stopped');
    expect(decoded.leaseReleased, isTrue);
  });
}
