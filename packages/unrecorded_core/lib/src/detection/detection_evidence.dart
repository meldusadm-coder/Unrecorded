/// Structured evidence for why a signal was assessed a certain way.
enum DetectionEvidenceKind {
  nameMatch,
  serviceUuidHint,
  manufacturerIdHint,
  addressPrefixHint,
  strongSignal,
  repeatedSighting,
  connectable,
  benignName,
  unknown,
}

class DetectionEvidence {
  const DetectionEvidence({
    required this.kind,
    required this.label,
  });

  final DetectionEvidenceKind kind;
  final String label;
}
