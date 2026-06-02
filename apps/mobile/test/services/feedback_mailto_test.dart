import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_mobile/copy/feedback_copy.dart';
import 'package:unrecorded_mobile/services/feedback_diagnostics.dart';
import 'package:unrecorded_mobile/services/feedback_draft.dart';
import 'package:unrecorded_mobile/services/feedback_mailto.dart';

void main() {
  const draft = FeedbackDraft(
    type: FeedbackType.falsePositive,
    message: 'The app flagged my headphones.',
    contactEmail: 'user@example.com',
  );

  test('subject includes feedback type label', () {
    expect(
      buildFeedbackSubject(draft),
      'Unrecorded feedback: False positive',
    );
  });

  test('body includes message and optional reply email', () {
    final body = buildFeedbackBody(draft);
    expect(body, contains('False positive'));
    expect(body, contains('The app flagged my headphones.'));
    expect(body, contains('Reply to: user@example.com'));
  });

  test('body excludes diagnostics when not provided', () {
    final body = buildFeedbackBody(draft);
    expect(body, isNot(contains('Diagnostic info')));
    expect(body, isNot(contains('Scanner mode')));
  });

  test('body includes opt-in diagnostics without scan identifiers', () {
    const diagnostics = FeedbackDiagnostics(
      entries: {
        'App version': '0.4.0',
        'Build': '9',
        'Platform': 'Android 14 / Pixel 7',
        'Scanner mode': 'demo',
        'Scan status': 'scanning',
      },
    );

    final body = buildFeedbackBody(draft, diagnostics: diagnostics);
    expect(body, contains('Diagnostic info (user opted in)'));
    expect(body, contains('Scanner mode: demo'));
    expect(body, isNot(contains('MAC')));
    expect(body, isNot(contains('RSSI')));
    expect(body, isNot(contains('BLE')));
  });

  test('mailto uri targets feedback inbox with encoded query', () {
    final uri = buildFeedbackMailtoUri(draft);
    expect(uri.scheme, 'mailto');
    expect(uri.path, FeedbackCopy.feedbackEmail);
    expect(uri.queryParameters['subject'], buildFeedbackSubject(draft));
    expect(uri.queryParameters['body'], buildFeedbackBody(draft));
  });

  test('github issue uri includes title and body query params', () {
    final uri = buildFeedbackGithubIssueUri(draft);
    expect(uri.host, 'github.com');
    expect(uri.path, '/meldusadm-coder/Unrecorded/issues/new');
    expect(uri.queryParameters['title'], buildFeedbackSubject(draft));
    expect(uri.queryParameters['body'], buildFeedbackBody(draft));
  });
}
