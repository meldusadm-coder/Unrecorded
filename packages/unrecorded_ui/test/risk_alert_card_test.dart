import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  group('RiskAlertCard', () {
    testWidgets('does not show Example label when isExample is false',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const RiskAlertCard(
            title: 'Possible recording risk nearby',
            body: 'A nearby device may be a smart glasses or wearable.',
          ),
        ),
      );
      expect(find.text('Example'), findsNothing);
    });

    testWidgets('shows Example label when isExample is true', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const RiskAlertCard(
            title: 'Possible recording risk nearby',
            body: 'A nearby device may be a smart glasses or wearable.',
            level: RiskLevel.high,
            isExample: true,
          ),
        ),
      );
      expect(find.text('Example'), findsOneWidget);
    });

    testWidgets('still shows title and body for both live and example cards',
        (tester) async {
      const title = 'Possible recording risk nearby';
      const body = 'A nearby device may be a smart glasses or wearable.';

      for (final isExample in [false, true]) {
        await tester.pumpWidget(
          _wrap(
            RiskAlertCard(title: title, body: body, isExample: isExample),
          ),
        );
        expect(find.text(title), findsOneWidget);
        expect(find.text(body), findsOneWidget);
      }
    });
  });
}
