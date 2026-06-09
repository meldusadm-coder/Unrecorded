import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';
import 'package:unrecorded_mobile/copy/feedback_copy.dart';
import 'package:unrecorded_mobile/app.dart';
import 'package:unrecorded_mobile/app_bootstrap.dart';
import 'package:unrecorded_mobile/features/help/help_screen.dart';
import 'package:unrecorded_mobile/services/ads_service.dart';
import 'package:unrecorded_mobile/services/scan_runtime.dart';
import 'package:unrecorded_mobile/services/scanner_config.dart';
import 'package:unrecorded_mobile/services/scanner_provider.dart';
import 'package:unrecorded_radio/unrecorded_radio.dart';

class _AndroidTestRuntime extends ScanRuntime {
  const _AndroidTestRuntime();

  @override
  bool get isAndroid => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget testApp({List<Override> extraOverrides = const []}) => ProviderScope(
        overrides: [
          adsServiceProvider.overrideWith((ref) async => AdsService()),
          scannerConfigProvider.overrideWith(
            (ref) => const ScannerConfig(
              mode: ScannerMode.demo,
              scenario: FakeDemoScenario.low,
            ),
          ),
          scannerConfigInitProvider.overrideWith((ref) async {}),
          ...extraOverrides,
        ],
        child: const AppBootstrap(child: UnrecordedApp()),
      );

  testWidgets('app renders scan screen with title', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pump();

    expect(find.text('Unrecorded'), findsOneWidget);
    expect(find.text(AppCopy.turnOnProtection), findsOneWidget);
  });

  testWidgets('protection button is shown on scan screen', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pump();

    expect(find.text(AppCopy.turnOnProtection), findsOneWidget);
  });

  testWidgets('navigates to help screen with example alert', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pump();

    await tester.tap(find.byTooltip('Help'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Example alert'), findsOneWidget);
    expect(find.text(AppCopy.alertCardTitle), findsOneWidget);
    expect(find.text(AppCopy.widgetHelpTitle), findsNothing);
  });

  testWidgets('help screen shows widget section on Android', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scanRuntimeProvider.overrideWithValue(const _AndroidTestRuntime()),
        ],
        child: const MaterialApp(home: HelpScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppCopy.widgetHelpTitle), findsOneWidget);
    expect(find.textContaining('Add the Unrecorded widget'), findsOneWidget);
    expect(find.textContaining('optional'), findsOneWidget);
    expect(find.text(AppCopy.notificationsHelpTitle), findsOneWidget);
    expect(find.textContaining('battery settings'), findsOneWidget);
  });

  testWidgets('help screen can navigate back to scan screen', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pump();

    await tester.tap(find.byTooltip('Help'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Help'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Unrecorded'), findsOneWidget);
    expect(find.text(AppCopy.turnOnProtection), findsOneWidget);
  });

  testWidgets('navigates to settings screen', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(testApp());
    await tester.pump();

    await tester.tap(find.byKey(const Key('settings_button')));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Settings & Privacy'), findsOneWidget);
    expect(find.text(AppCopy.riskNotificationsTitle), findsOneWidget);
    expect(find.text('Local-first'), findsOneWidget);

    final alertsY =
        tester.getTopLeft(find.text(AppCopy.riskNotificationsTitle)).dy;
    final localFirstY = tester.getTopLeft(find.text('Local-first')).dy;
    expect(alertsY, lessThan(localFirstY));
  });

  testWidgets('settings screen can navigate back to scan screen',
      (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pump();

    await tester.tap(find.byKey(const Key('settings_button')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Settings & Privacy'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Unrecorded'), findsOneWidget);
  });

  testWidgets('shows a single bottom ad slot when navigating to help',
      (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pump();

    await tester.tap(find.byTooltip('Help'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byType(BottomAdSlot), findsOneWidget);
  });

  testWidgets('navigates to feedback from settings', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(testApp());
    await tester.pump();

    await tester.tap(find.byKey(const Key('settings_button')));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.byKey(const Key('settings_feedback_tile')));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text(FeedbackCopy.screenTitle), findsOneWidget);
    expect(find.text(FeedbackCopy.privacyNote), findsOneWidget);
  });

  testWidgets('navigates to feedback from help', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(testApp());
    await tester.pump();

    await tester.tap(find.byTooltip('Help'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.scrollUntilVisible(
      find.byKey(const Key('help_feedback_tile')),
      100,
    );
    await tester.tap(find.byKey(const Key('help_feedback_tile')));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text(FeedbackCopy.screenTitle), findsOneWidget);
  });
}
