import '../copy/feedback_copy.dart';
import 'feedback_diagnostics.dart';
import 'feedback_draft.dart';

String buildFeedbackSubject(FeedbackDraft draft) {
  return 'Unrecorded feedback: ${draft.type.label}';
}

String buildFeedbackBody(
  FeedbackDraft draft, {
  FeedbackDiagnostics? diagnostics,
}) {
  final buffer = StringBuffer()
    ..writeln('Feedback type: ${draft.type.label}')
    ..writeln()
    ..writeln(draft.message.trim());

  final email = draft.contactEmail?.trim();
  if (email != null && email.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('Reply to: $email');
  }

  if (diagnostics != null) {
    buffer
      ..writeln()
      ..writeln('--- Diagnostic info (user opted in) ---');
    for (final entry in diagnostics.entries.entries) {
      buffer.writeln('${entry.key}: ${entry.value}');
    }
  }

  return buffer.toString().trim();
}

Uri buildFeedbackMailtoUri(
  FeedbackDraft draft, {
  FeedbackDiagnostics? diagnostics,
}) {
  return Uri(
    scheme: 'mailto',
    path: FeedbackCopy.feedbackEmail,
    queryParameters: {
      'subject': buildFeedbackSubject(draft),
      'body': buildFeedbackBody(draft, diagnostics: diagnostics),
    },
  );
}

Uri buildFeedbackGithubIssueUri(
  FeedbackDraft draft, {
  FeedbackDiagnostics? diagnostics,
}) {
  return Uri.parse(FeedbackCopy.githubNewIssueBase).replace(
    queryParameters: {
      'title': buildFeedbackSubject(draft),
      'body': buildFeedbackBody(draft, diagnostics: diagnostics),
    },
  );
}
