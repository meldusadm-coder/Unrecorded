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
}
