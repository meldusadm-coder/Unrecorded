import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_mobile/app.dart';
import 'package:unrecorded_mobile/app_bootstrap.dart';
import 'package:unrecorded_mobile/services/ads_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget testApp() => ProviderScope(
        overrides: [
          adsServiceProvider.overrideWith((ref) async => AdsService()),
        ],
        child: const AppBootstrap(child: UnrecordedApp()),
      );

  testWidgets('app renders scan screen with title', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pump();

    expect(find.text('Unrecorded'), findsOneWidget);
    expect(find.text(AppCopy.turnOnProtection), findsOneWidget);
  });

  testWidgets('protection button toggles to pause', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pump();

    await tester.tap(find.text(AppCopy.turnOnProtection));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text(AppCopy.pauseProtection).evaluate().isNotEmpty) break;
    }

    expect(find.text(AppCopy.pauseProtection), findsOneWidget);
  });

  testWidgets('navigates to help screen with example alert', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pump();

    await tester.tap(find.byTooltip('Help'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Example alert'), findsOneWidget);
    expect(find.text(AppCopy.alertCardTitle), findsOneWidget);
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
    expect(find.text('Local-first'), findsOneWidget);
  });
}
