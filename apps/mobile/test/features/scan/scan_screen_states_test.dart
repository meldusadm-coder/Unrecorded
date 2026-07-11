import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_mobile/features/scan/scan_screen.dart';
import 'package:unrecorded_mobile/features/scan/scan_state.dart';
import 'package:unrecorded_mobile/features/scan/signal_ui_model.dart';
import 'package:unrecorded_mobile/services/background_protection_controller.dart';
import 'package:unrecorded_mobile/services/background_protection_preflight.dart';
import 'package:unrecorded_mobile/services/risk_notification_service.dart';
import 'package:unrecorded_mobile/services/scanner_provider.dart';
import 'package:unrecorded_mobile/services/widget_sync_service.dart';

import '../../support/fake_foreground_service_controller.dart';
import '../../support/scan_test_harness.dart';

class _AndroidTestRuntime extends NoopScanRuntime {
  const _AndroidTestRuntime();

  @override
  bool get isAndroid => true;
}

class _OkBackgroundPreflight extends BackgroundProtectionPreflight {
  _OkBackgroundPreflight()
      : super(
          runtime: const NoopScanRuntime(),
          notifications: RiskNotificationService(
            RiskNotificationService.sharedPlugin,
          ),
        );

  int checkCount = 0;

  @override
  Future<BackgroundProtectionPreflightResult> check({
    bool requestPermissions = true,
  }) async {
    checkCount++;
    return const BackgroundProtectionPreflightResult.ok();
  }
}

class _ToggleHarnessBackgroundController
    extends BackgroundProtectionController {
  _ToggleHarnessBackgroundController(this.preflight)
      : super(
          foregroundService: FakeForegroundServiceController(),
          preflight: preflight,
          isAndroidPlatform: true,
          applyMirroredScanState: (_) {},
          pauseMainProtection: () async {},
          onServiceRunningChanged: (_) {},
        );

  final _OkBackgroundPreflight preflight;

  @override
  Future<bool> enable() async {
    await preflight.check();
    state = state.copyWith(enabled: true, serviceRunning: true);
    return true;
  }

  @override
  Future<void> disable({bool recordExplicitStop = true}) async {
    state = const BackgroundProtectionState();
  }
}

class _CountingScanController extends StateHarnessController {
  _CountingScanController(super.value);

  int startCount = 0;
  int pauseCount = 0;

  void setScanState(ScanState value) {
    state = value;
  }

  @override
  Future<void> startProtection({bool persist = true}) async {
    startCount++;
    state = state.copyWith(
      status: ScanStatus.starting,
      protectionRequested: true,
    );
  }

  @override
  Future<void> pauseProtection({bool persist = true}) async {
    pauseCount++;
    state = state.copyWith(
      status: ScanStatus.paused,
      protectionRequested: false,
    );
  }
}

Future<void> _pumpWithControllers(
  WidgetTester tester, {
  required _CountingScanController scanController,
  _ToggleHarnessBackgroundController? backgroundController,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        scanRuntimeProvider.overrideWithValue(const _AndroidTestRuntime()),
        scanControllerProvider.overrideWith((ref) => scanController),
        widgetSyncServiceProvider
            .overrideWith((ref) => const WidgetSyncService()),
        if (backgroundController != null)
          backgroundProtectionControllerProvider
              .overrideWith((ref) => backgroundController),
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

  testWidgets('routine scan phases display only simple protection on state',
      (tester) async {
    for (final status in [
      ScanStatus.scanning,
      ScanStatus.resting,
      ScanStatus.confirmingRisk,
    ]) {
      await pumpScanScreen(
        tester,
        ScanState(status: status, protectionRequested: true),
      );

      expect(find.text('Protection is on'), findsOneWidget);
      expect(find.text(AppCopy.scanResting), findsNothing);
      expect(find.text(AppCopy.confirmingRisk), findsNothing);
    }
  });

  testWidgets('main protection control starts and pauses protection',
      (tester) async {
    final controller = _CountingScanController(const ScanState());
    await _pumpWithControllers(tester, scanController: controller);

    await tester.tap(find.byKey(const Key('main_protection_control')));
    await tester.pump();
    expect(controller.startCount, 1);
    expect(find.text('Starting protection…'), findsOneWidget);

    controller.setScanState(
      const ScanState(
        status: ScanStatus.scanning,
        protectionRequested: true,
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('main_protection_control')));
    await tester.pump();
    expect(controller.pauseCount, 1);
  });

  testWidgets('starting state disables rapid repeated taps', (tester) async {
    final controller = _CountingScanController(
      const ScanState(status: ScanStatus.starting, protectionRequested: true),
    );
    await _pumpWithControllers(tester, scanController: controller);

    await tester.tap(find.byKey(const Key('main_protection_control')));
    await tester.tap(find.byKey(const Key('main_protection_control')));
    await tester.pump();

    expect(controller.startCount, 0);
  });

  testWidgets('blocked states expose disabled primary control semantics',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpScanScreen(
      tester,
      const ScanState(status: ScanStatus.permissionDenied),
    );

    final node = tester.getSemantics(
      find.byKey(const Key('main_protection_control_semantics')),
    );
    expect(node.label, AppCopy.protectionControlOff);
    expect(node.hint, isEmpty);
    semantics.dispose();
  });

  testWidgets('background protection toggle is secondary and requests on tap',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final preflight = _OkBackgroundPreflight();
    final backgroundController = _ToggleHarnessBackgroundController(preflight);
    await _pumpWithControllers(
      tester,
      scanController: _CountingScanController(const ScanState()),
      backgroundController: backgroundController,
    );

    expect(find.text(AppCopy.backgroundProtectionTitle), findsOneWidget);
    expect(find.byKey(const Key('background_protection_info')), findsOneWidget);
    expect(
      tester
          .getSemantics(
            find.byKey(const Key('background_protection_switch_semantics')),
          )
          .label,
      AppCopy.backgroundProtectionTitle,
    );
    expect(find.text(AppCopy.backgroundProtectionSubtitle), findsNothing);
    expect(preflight.checkCount, 0);

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(preflight.checkCount, 1);
    expect(backgroundController.state.enabled, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(preflight.checkCount, 1);
    expect(backgroundController.state.enabled, isFalse);
    semantics.dispose();
  });

  testWidgets('background protection helper expands on demand', (tester) async {
    await _pumpWithControllers(
      tester,
      scanController: _CountingScanController(const ScanState()),
      backgroundController:
          _ToggleHarnessBackgroundController(_OkBackgroundPreflight()),
    );

    expect(find.text(AppCopy.backgroundProtectionSubtitle), findsNothing);
    await tester.tap(find.byKey(const Key('background_protection_info')));
    await tester.pumpAndSettle();
    expect(find.text(AppCopy.backgroundProtectionSubtitle), findsOneWidget);
  });

  testWidgets('advanced information is collapsed by default', (tester) async {
    await pumpScanScreen(
      tester,
      const ScanState(
        status: ScanStatus.scanning,
        protectionRequested: true,
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

    expect(find.text('More information and settings'), findsOneWidget);
    expect(find.text('Why this risk level?'), findsNothing);
    expect(find.text(AppCopy.scanHelper), findsNothing);

    await tester.tap(find.text('More information and settings'));
    await tester.pumpAndSettle();

    expect(find.text('Why this risk level?'), findsOneWidget);
    expect(find.text(AppCopy.scanHelper), findsOneWidget);
  });
}
