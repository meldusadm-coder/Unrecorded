import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_mobile/app.dart';

void main() {
  testWidgets('app renders scan screen with title', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: UnrecordedApp()));
    await tester.pumpAndSettle();

    expect(find.text('Unrecorded'), findsOneWidget);
    expect(find.text('Start scanning'), findsOneWidget);
  });

  testWidgets('start scanning button toggles to stop', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: UnrecordedApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start scanning'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Stop scanning'), findsOneWidget);
  });

  testWidgets('navigates to alert explanation screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: UnrecordedApp()));
    await tester.pumpAndSettle();

    final infoButton = find.byWidgetPredicate(
      (w) => w is IconButton && w.tooltip == 'How detection works',
    );
    await tester.tap(infoButton);
    await tester.pumpAndSettle();

    expect(find.text('Why you may see a warning'), findsOneWidget);
  });

  testWidgets('navigates to settings screen', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: UnrecordedApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings_button')));
    await tester.pumpAndSettle();

    expect(find.text('Settings & Privacy'), findsOneWidget);
    expect(find.text('Local-first'), findsOneWidget);
  });
}
