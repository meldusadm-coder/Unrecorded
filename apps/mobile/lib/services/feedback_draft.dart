/// User-selected feedback category.
enum FeedbackType {
  bug('Bug'),
  confusingWording('Confusing wording'),
  falsePositive('False positive'),
  missedAlert('Missed/expected alert'),
  featureIdea('Feature idea'),
  other('Other');

  const FeedbackType(this.label);

  final String label;
}

/// In-app feedback form contents before submission.
class FeedbackDraft {
  const FeedbackDraft({
    required this.type,
    required this.message,
    this.contactEmail,
    this.includeDiagnostics = false,
  });

  final FeedbackType type;
  final String message;
  final String? contactEmail;
  final bool includeDiagnostics;
}
