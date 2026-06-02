import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_mobile/features/scan/scan_screen.dart';
import 'package:unrecorded_mobile/features/scan/scan_state.dart';
import 'package:unrecorded_mobile/features/scan/signal_ui_model.dart';
import 'package:unrecorded_mobile/services/scan_lifecycle_coordinator.dart';
import 'package:unrecorded_mobile/services/scan_runtime.dart';
import 'package:unrecorded_mobile/services/scanner_provider.dart';
import 'package:unrecorded_mobile/services/signal_ui_mapper.dart';
import 'package:unrecorded_mobile/services/widget_sync_service.dart';
import 'package:unrecorded_radio/unrecorded_radio.dart';

class _NoopRuntime extends ScanRuntime {
  const _NoopRuntime();

  @override
  bool get isAndroid => false;
}

class _StateHarnessController extends ScanController {
  _StateHarnessController(ScanState value)
      : super(
          coordinator: ScanLifecycleCoordinator(
            scannerFactory: () => FakeRadioScanner(),
            runtime: const _NoopRuntime(),
            scannerModeFactory: () => ScannerMode.demo,
            pipeline: DetectionPipeline(),
          ),
          pipeline: DetectionPipeline(),
          mapper: const SignalUiMapper(),
        ) {
    state = value;
  }
}

Future<void> _pumpState(WidgetTester tester, ScanState state) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        scanControllerProvider
            .overrideWith((ref) => _StateHarnessController(state)),
        widgetSyncServiceProvider
            .overrideWith((ref) => const WidgetSyncService()),
      ],
      child: const MaterialApp(home: ScanScreen()),
    ),
  );
  await tester.pump();
}

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
      await _pumpState(tester, state);
      expect(find.text('Unrecorded'), findsOneWidget);
    }
  });

  testWidgets('shows demo banner when demo mode protection is active',
      (tester) async {
    await _pumpState(
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
    await _pumpState(
      tester,
      const ScanState(
        status: ScanStatus.possibleRiskDetected,
        protectionRequested: true,
        riskLevel: RiskLevel.medium,
        reasons: ['Potential nearby match'],
        possibleRiskSignals: [
          SignalUiModel(
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
