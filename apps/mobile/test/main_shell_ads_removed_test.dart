import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unrecorded_mobile/main_shell.dart';
import 'package:unrecorded_mobile/services/ads_service.dart';
import 'package:unrecorded_mobile/services/entitlement_service.dart';

import 'support/fake_in_app_purchase.dart';

Widget _shellHarness({
  String location = '/help',
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      adsServiceProvider.overrideWith((ref) async => AdsService()),
      entitlementServiceProvider.overrideWith((ref) async {
        final prefs = await SharedPreferences.getInstance();
        final service = EntitlementService(
          prefs,
          iap: FakeInAppPurchase(),
          onChanged: () {
            ref.read(entitlementRefreshProvider.notifier).state++;
          },
        );
        await service.init();
        return service;
      }),
      ...overrides,
    ],
    child: MaterialApp(
      home: Scaffold(
        body: MainShell(
          location: location,
          child: const SizedBox.shrink(),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('hides bottom ad slot when ads may not show (override)',
      (tester) async {
    await tester.pumpWidget(
      _shellHarness(
        overrides: [
          adsMayShowProvider.overrideWith((ref) => false),
        ],
      ),
    );

    await tester.pump();

    expect(find.text('Remove ads'), findsNothing);
    expect(find.byType(ClipRect), findsNothing);
  });

  testWidgets('banner ad widget provider returns null when ads may not show',
      (tester) async {
    Widget? bannerWidget;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adsMayShowProvider.overrideWith((ref) => false),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            bannerWidget = ref.watch(bannerAdWidgetProvider);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await tester.pump();
    expect(bannerWidget, isNull);
  });

  testWidgets('prefs ads_removed hides slot without provider override',
      (tester) async {
    SharedPreferences.setMockInitialValues({'ads_removed': true});

    await tester.pumpWidget(_shellHarness());
    await tester.pumpAndSettle();

    expect(find.text('Remove ads'), findsNothing);
    expect(find.byType(ClipRect), findsNothing);
  });
}
