import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unrecorded_mobile/app.dart';
import 'package:unrecorded_mobile/app_bootstrap.dart';
import 'package:unrecorded_mobile/router.dart';
import 'package:unrecorded_mobile/services/ads_service.dart';
import 'package:unrecorded_mobile/services/scan_runtime.dart';
import 'package:unrecorded_mobile/services/scanner_config.dart';
import 'package:unrecorded_mobile/services/scanner_provider.dart';
import 'package:unrecorded_radio/unrecorded_radio.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget testApp() => ProviderScope(
        overrides: [
          adsServiceProvider.overrideWith((ref) async => AdsService()),
          scannerConfigProvider.overrideWith(
            (ref) => const ScannerConfig(
              mode: ScannerMode.demo,
              scenario: FakeDemoScenario.high,
            ),
          ),
          scannerConfigInitProvider.overrideWith((ref) async {}),
        ],
        child: const AppBootstrap(child: UnrecordedApp()),
      );

  testWidgets('view details opens alert details with device name', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(testApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    refInjectHighRisk(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    navigateToAlertDetails();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Alert details'), findsOneWidget);
    expect(find.text('Ray-Ban Meta'), findsOneWidget);
    expect(find.text('Possible smart glasses / wearable'), findsOneWidget);
    expect(find.byType(RiskBadge), findsWidgets);
  });
}

void refInjectHighRisk(WidgetTester tester) {
  final element = tester.element(find.byType(UnrecordedApp));
  final container = ProviderScope.containerOf(element);
  container.read(scanControllerProvider.notifier).simulateHighRiskAlert();
}
