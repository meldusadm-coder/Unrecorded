/// Cautious confidence band for UI (not proof of recording).
enum ConfidenceBand {
  low,
  moderate,
  elevated,
}

extension ConfidenceBandLabel on ConfidenceBand {
  String get label => switch (this) {
        ConfidenceBand.low => 'Low confidence',
        ConfidenceBand.moderate => 'Moderate confidence',
        ConfidenceBand.elevated => 'Elevated confidence',
      };
}
