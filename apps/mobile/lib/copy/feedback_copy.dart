/// App-only copy for the feedback feature.
class FeedbackCopy {
  FeedbackCopy._();

  static const String sendFeedbackButton = 'Send feedback';

  static const String screenTitle = 'Feedback';

  static const String intro =
      'Help improve Unrecorded by telling us what was confusing, broken, '
      'or missing.';

  static const String privacyNote =
      'Please do not include private conversations, names of people nearby, '
      'or sensitive details. Scan data stays on your device unless you '
      'explicitly choose to share a summary.';

  static const String typeLabel = 'Feedback type';

  static const String messageLabel = 'Your message';

  static const String messageHelper =
      'Tell us what happened. Please avoid including private information '
      'or names of people nearby.';

  static const String contactEmailLabel = 'Contact email (optional)';

  static const String contactEmailHelper =
      'Optional — only if you want a reply.';

  static const String diagnosticsTitle = 'Include basic diagnostic info';

  static const String diagnosticsSubtitle =
      'If enabled, your email may include app version, device model, '
      'scanner mode, and scan status. No nearby device names or Bluetooth '
      'identifiers are included.';

  static const String submitSuccess =
      'Thanks — your feedback helps make Unrecorded clearer and safer to use.';

  static const String fallbackTitle = 'Could not open email app';

  static const String fallbackBody =
      'No email app was found on this device. You can copy the address '
      'below or open GitHub to send your feedback another way.';

  static const String fallbackCopyEmail = 'Copy email address';

  static const String fallbackOpenGithub = 'Open on GitHub';

  static const String emailCopied = 'Email address copied';

  static const String invalidEmail = 'Please enter a valid email address';

  static const String feedbackEmail = 'feedback@unrecorded.app';

  static const String githubNewIssueBase =
      'https://github.com/meldusadm-coder/Unrecorded/issues/new';
}
