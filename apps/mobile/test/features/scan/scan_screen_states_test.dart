import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_mobile/features/scan/scan_state.dart';
import 'package:unrecorded_mobile/features/scan/signal_ui_model.dart';

import '../../support/scan_test_harness.dart';

void main() {
  testWidgets('renders scan screen without crashing across key states',
      (tester) async {
    final states = <ScanState>[
      const ScanState(status: ScanStatus.idle),
      const ScanState(status: ScanStatus.starting, protectionRequested: true),
      const ScanState(status: ScanStatus.scanning, protectionRequested: true),
      const ScanState(status: ScanStatus.resting, protectionRequested: true),
      const ScanState(
        status: ScanStatus.confirmingRisk,
        protectionRequested: true,
      ),
      const ScanState(
        status: ScanStatus.possibleRiskDetected,
        protectionRequested: true,
      ),
      const ScanState(status: ScanStatus.paused),
      const ScanState(status: ScanStatus.permissionDenied),
      const ScanState(status: ScanStatus.permissionPermanentlyDenied),
      const ScanState(status: ScanStatus.bluetoothOff),
      const ScanState(status: ScanStatus.bluetoothUnsupported),
      const ScanState(status: ScanStatus.error),
    ];

    for (final state in states) {
      await pumpScanScreen(tester, state);
      expect(find.text('Unrecorded'), findsOneWidget);
    }
  });

  testWidgets('shows demo banner when demo mode protection is active',
      (tester) async {
    await pumpScanScreen(
      tester,
      const ScanState(
        status: ScanStatus.scanning,
        protectionRequested: true,
        isDemoMode: true,
      ),
    );
    expect(find.text(AppCopy.demoModeBanner), findsOneWidget);
  });

  testWidgets('possible risk state shows alert helper and uncertainty copy',
      (tester) async {
    await pumpScanScreen(
      tester,
      const ScanState(
        status: ScanStatus.possibleRiskDetected,
        protectionRequested: true,
        riskLevel: RiskLevel.medium,
        reasons: ['Potential nearby match'],
        possibleRiskSignals: [
          SignalUiModel(
            stableKey: 'ray-ban-meta',
            title: 'Ray-Ban Meta',
            categoryLabel: 'Possible recording wearable',
            confidenceLabel: 'Elevated confidence',
            evidenceLabels: ['Name match'],
            lastSeenLabel: 'just now',
            signalStrengthLabel: 'Strong',
            contributesToRisk: true,
          ),
        ],
      ),
    );

    expect(find.text(AppCopy.alertCardTitle), findsWidgets);
  });
}
