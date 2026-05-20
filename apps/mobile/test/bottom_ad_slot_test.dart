import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

void main() {
  testWidgets('Remove ads tap fires callback without hitting ad child',
      (tester) async {
    var removeAdsTapped = false;
    var adTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BottomAdSlot(
            onRemoveAdsTap: () => removeAdsTapped = true,
            child: GestureDetector(
              onTap: () => adTapped = true,
              child: Container(
                key: const Key('mock_ad'),
                color: Colors.red,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Remove ads'));
    await tester.pump();

    expect(removeAdsTapped, isTrue);
    expect(adTapped, isFalse);
  });

  testWidgets('BottomAdSlot hidden when showSlot is false', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BottomAdSlot(
            showSlot: false,
            onRemoveAdsTap: null,
          ),
        ),
      ),
    );

    expect(find.text('Remove ads'), findsNothing);
  });
}
