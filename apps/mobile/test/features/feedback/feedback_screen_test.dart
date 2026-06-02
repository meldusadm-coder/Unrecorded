import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unrecorded_mobile/copy/feedback_copy.dart';
import 'package:unrecorded_mobile/features/feedback/feedback_screen.dart';
import 'package:unrecorded_mobile/services/ads_service.dart';
import 'package:unrecorded_mobile/services/feedback_launcher.dart';
import 'package:unrecorded_mobile/services/scanner_config.dart';
import 'package:unrecorded_mobile/services/scanner_provider.dart';
import 'package:unrecorded_mobile/services/scan_runtime.dart';
import 'package:unrecorded_radio/unrecorded_radio.dart';

Finder submitButtonFinder() => find.descendant(
      of: find.byKey(const Key('feedback_submit_button')),
      matching: find.byType(FilledButton),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> openFeedbackScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.tap(find.text('Open feedback'));
    await tester.pumpAndSettle();
  }

  Widget buildScreen({
    FeedbackSubmitFn? submitFn,
  }) =>
      ProviderScope(
        overrides: [
          adsServiceProvider.overrideWith((ref) async => AdsService()),
          scannerConfigProvider.overrideWith(
            (ref) => const ScannerConfig(
              mode: ScannerMode.demo,
              scenario: FakeDemoScenario.low,
            ),
          ),
          scannerConfigInitProvider.overrideWith((ref) async {}),
          if (submitFn != null)
            feedbackSubmitFnProvider.overrideWith((ref) => submitFn),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const FeedbackScreen(),
                    ),
                  ),
                  child: const Text('Open feedback'),
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets('renders feedback form fields and privacy note', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pump();

    await openFeedbackScreen(tester);

    expect(find.text(FeedbackCopy.screenTitle), findsOneWidget);
    expect(find.text(FeedbackCopy.intro), findsOneWidget);
    expect(find.text(FeedbackCopy.privacyNote), findsOneWidget);
    expect(find.byKey(const Key('feedback_message_field')), findsOneWidget);
    expect(find.byKey(const Key('feedback_email_field')), findsOneWidget);
    expect(
      find.byKey(const Key('feedback_diagnostics_switch')),
      findsOneWidget,
    );
  });

  testWidgets('send button disabled until message entered', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pump();

    await openFeedbackScreen(tester);

    expect(tester.widget<FilledButton>(submitButtonFinder()).onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('feedback_message_field')),
      'The scan state was unclear.',
    );
    await tester.pump();

    expect(
      tester.widget<FilledButton>(submitButtonFinder()).onPressed,
      isNotNull,
    );
  });

  testWidgets('successful submit shows success snackbar', (tester) async {
    await tester.pumpWidget(
      buildScreen(
        submitFn: (_) async => true,
      ),
    );
    await tester.pump();

    await openFeedbackScreen(tester);

    await tester.enterText(
      find.byKey(const Key('feedback_message_field')),
      'Permissions explanation is confusing.',
    );
    await tester.pump();

    await tester.tap(submitButtonFinder());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(FeedbackCopy.submitSuccess), findsOneWidget);
  });

  testWidgets('failed submit shows fallback dialog', (tester) async {
    await tester.pumpWidget(
      buildScreen(
        submitFn: (_) async => false,
      ),
    );
    await tester.pump();

    await openFeedbackScreen(tester);

    await tester.enterText(
      find.byKey(const Key('feedback_message_field')),
      'Something is broken.',
    );
    await tester.pump();

    await tester.tap(submitButtonFinder());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(FeedbackCopy.fallbackTitle), findsOneWidget);
    expect(find.text(FeedbackCopy.feedbackEmail), findsOneWidget);
    expect(find.text(FeedbackCopy.fallbackOpenGithub), findsOneWidget);
  });

  testWidgets('invalid optional email shows validation error', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pump();

    await openFeedbackScreen(tester);

    await tester.enterText(
      find.byKey(const Key('feedback_message_field')),
      'Need help understanding alerts.',
    );
    await tester.enterText(
      find.byKey(const Key('feedback_email_field')),
      'not-an-email',
    );
    await tester.pump();

    await tester.tap(submitButtonFinder());
    await tester.pump();

    expect(find.text(FeedbackCopy.invalidEmail), findsOneWidget);
  });
}
