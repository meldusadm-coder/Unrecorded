/// UI-facing model for one nearby signal (no raw BLE complexity).
class SignalUiModel {
  const SignalUiModel({
    required this.title,
    required this.categoryLabel,
    required this.confidenceLabel,
    required this.evidenceLabels,
    required this.lastSeenLabel,
    required this.signalStrengthLabel,
    required this.contributesToRisk,
  });

  final String title;
  final String categoryLabel;
  final String confidenceLabel;
  final List<String> evidenceLabels;
  final String lastSeenLabel;
  final String signalStrengthLabel;
  final bool contributesToRisk;
}
