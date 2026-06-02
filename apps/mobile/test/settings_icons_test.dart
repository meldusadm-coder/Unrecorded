import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_mobile/app.dart';
import 'package:unrecorded_mobile/copy/monetisation_copy.dart';
import 'package:unrecorded_mobile/app_bootstrap.dart';
import 'package:unrecorded_mobile/services/ad_consent_service.dart';
import 'package:unrecorded_mobile/services/ads_service.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

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

  testWidgets('settings shows Alerts before privacy tiles', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(testApp());
    await tester.pump();

    await tester.tap(find.byKey(const Key('settings_button')));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text(AppCopy.riskNotificationsTitle), findsOneWidget);
    expect(find.text('Local-first'), findsOneWidget);

    final alertsY = tester.getTopLeft(find.text('Alerts')).dy;
    final localFirstY = tester.getTopLeft(find.text('Local-first')).dy;
    expect(alertsY, lessThan(localFirstY));
  });

  testWidgets('settings privacy tiles use brand icons not broken_image',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(testApp());
    await tester.pump();

    await tester.tap(find.byKey(const Key('settings_button')));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
    expect(find.byType(UnrecordedIcon), findsWidgets);
    expect(find.byType(AppLogo), findsWidgets);
  });

  testWidgets('notify threshold dropdown uses brand icons', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'risk_notifications_enabled': true,
      'notification_risk_threshold': 'highOnly',
    });

    await tester.pumpWidget(testApp());
    await tester.pump();
    await tester.tap(find.byKey(const Key('settings_button')));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text(AppCopy.riskNotificationLevelTitle), findsWidgets);
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
    expect(find.byType(UnrecordedIcon), findsWidgets);
  });

  testWidgets('settings shows ad privacy choices when UMP requires it',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adsServiceProvider.overrideWith((ref) async => AdsService()),
          adPrivacyOptionsRequiredProvider.overrideWith((ref) async => true),
        ],
        child: const AppBootstrap(child: UnrecordedApp()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('settings_button')));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byKey(const Key('ad_privacy_choices_tile')), findsOneWidget);
    expect(find.text(MonetisationCopy.adPrivacyChoicesTitle), findsOneWidget);
  });
}
