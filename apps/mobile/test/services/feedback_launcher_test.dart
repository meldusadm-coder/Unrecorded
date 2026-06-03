import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_mobile/services/feedback_draft.dart';
import 'package:unrecorded_mobile/services/feedback_launcher.dart';
import 'package:unrecorded_mobile/services/feedback_mailto.dart';

void main() {
  const draft = FeedbackDraft(
    type: FeedbackType.bug,
    message: 'Example',
  );

  group('feedbackUriRequiresCanLaunchCheck', () {
    test('requires check for mailto', () {
      final uri = buildFeedbackMailtoUri(draft);
      expect(feedbackUriRequiresCanLaunchCheck(uri), isTrue);
    });

    test('skips check for https github issue links', () {
      final uri = buildFeedbackGithubIssueUri(draft);
      expect(uri.scheme, 'https');
      expect(feedbackUriRequiresCanLaunchCheck(uri), isFalse);
    });

    test('skips check for http', () {
      expect(
        feedbackUriRequiresCanLaunchCheck(
          Uri.parse('http://example.com'),
        ),
        isFalse,
      );
    });

    test('treats scheme case-insensitively', () {
      expect(
        feedbackUriRequiresCanLaunchCheck(
          Uri.parse('HTTPS://github.com/example/repo'),
        ),
        isFalse,
      );
    });
  });
}
