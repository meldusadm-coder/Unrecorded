import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_mobile/features/scan/scan_state.dart';
import 'package:unrecorded_mobile/features/scan/signal_ui_model.dart';
import 'package:unrecorded_mobile/features/scan/protection_hero.dart';

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
      expect(find.byType(ProtectionHero), findsOneWidget);
    }
  });

  testWidgets('shows demo chip when demo mode protection is active',
      (tester) async {
    await pumpScanScreen(
      tester,
      const ScanState(
        status: ScanStatus.scanning,
        protectionRequested: true,
        isDemoMode: true,
      ),
    );
    expect(find.text('Demo'), findsOneWidget);
  });

  testWidgets('possible risk state shows hero alert and uncertainty copy',
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

    expect(find.text(AppCopy.possibleRiskTitle), findsWidgets);
    expect(find.text(AppCopy.notProofOfRecording), findsOneWidget);
    expect(find.text('View details'), findsOneWidget);
    expect(find.text('Dismiss'), findsOneWidget);
    expect(find.text('Ray-Ban Meta'), findsWidgets);
    expect(find.byKey(const Key('scan_feedback_link')), findsNothing);
  });

  testWidgets('off state shows turn on protection', (tester) async {
    await pumpScanScreen(tester, const ScanState());
    expect(find.text(AppCopy.turnOnProtection), findsOneWidget);
    expect(find.text('Protection is off'), findsOneWidget);
  });
}
