import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_mobile/main_shell.dart';
import 'package:unrecorded_mobile/services/ads_service.dart';
import 'package:unrecorded_mobile/services/entitlement_service.dart';

void main() {
  testWidgets('hides bottom ad slot content when ads are removed', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adsRemovedProvider.overrideWith((ref) => true),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: MainShell(
              location: '/',
              child: SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Remove ads'), findsNothing);
    expect(find.byType(ClipRect), findsNothing);
  });

  testWidgets('banner ad widget provider returns null when ads are removed',
      (tester) async {
    Widget? bannerWidget;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adsRemovedProvider.overrideWith((ref) => true),
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
}
