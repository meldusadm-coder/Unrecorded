/// Phrase-level benign categories for safe-device classification.
class BenignPhrase {
  const BenignPhrase(this.phrase, this.category);

  final String phrase;
  final BenignDeviceCategory category;
}

enum BenignDeviceCategory {
  audio,
  input,
  mediaTv,
  wearableFitness,
  vehicle,
}

/// Broad terms use word-boundary style matching to reduce false suppression.
const List<BenignPhrase> benignPhrases = [
  BenignPhrase('airpods', BenignDeviceCategory.audio),
  BenignPhrase('airpod', BenignDeviceCategory.audio),
  BenignPhrase('galaxy buds', BenignDeviceCategory.audio),
  BenignPhrase('buds pro', BenignDeviceCategory.audio),
  BenignPhrase('buds live', BenignDeviceCategory.audio),
  BenignPhrase('buds2', BenignDeviceCategory.audio),
  BenignPhrase('earbuds', BenignDeviceCategory.audio),
  BenignPhrase('earbud', BenignDeviceCategory.audio),
  BenignPhrase('headphones', BenignDeviceCategory.audio),
  BenignPhrase('headphone', BenignDeviceCategory.audio),
  BenignPhrase('beats', BenignDeviceCategory.audio),
  BenignPhrase('jbl', BenignDeviceCategory.audio),
  BenignPhrase('bose', BenignDeviceCategory.audio),
  BenignPhrase('sony wh', BenignDeviceCategory.audio),
  BenignPhrase('quietcomfort', BenignDeviceCategory.audio),
  BenignPhrase('soundlink', BenignDeviceCategory.audio),
  BenignPhrase('speaker', BenignDeviceCategory.audio),
  BenignPhrase('soundbar', BenignDeviceCategory.audio),
  BenignPhrase('sound bar', BenignDeviceCategory.audio),
  BenignPhrase('keyboard', BenignDeviceCategory.input),
  BenignPhrase('mouse', BenignDeviceCategory.input),
  BenignPhrase('trackpad', BenignDeviceCategory.input),
  BenignPhrase('metalab keyboard', BenignDeviceCategory.input),
  BenignPhrase('smart tv', BenignDeviceCategory.mediaTv),
  BenignPhrase('television', BenignDeviceCategory.mediaTv),
  BenignPhrase('roku', BenignDeviceCategory.mediaTv),
  BenignPhrase('chromecast', BenignDeviceCategory.mediaTv),
  BenignPhrase('fire tv', BenignDeviceCategory.mediaTv),
  BenignPhrase('lg tv', BenignDeviceCategory.mediaTv),
  BenignPhrase('samsung tv', BenignDeviceCategory.mediaTv),
  BenignPhrase('fitbit', BenignDeviceCategory.wearableFitness),
  BenignPhrase('garmin', BenignDeviceCategory.wearableFitness),
  BenignPhrase('whoop', BenignDeviceCategory.wearableFitness),
  BenignPhrase('amazfit', BenignDeviceCategory.wearableFitness),
  BenignPhrase('polar', BenignDeviceCategory.wearableFitness),
  BenignPhrase('oura', BenignDeviceCategory.wearableFitness),
  BenignPhrase('apple watch', BenignDeviceCategory.wearableFitness),
  BenignPhrase('uconnect', BenignDeviceCategory.vehicle),
  BenignPhrase('carplay', BenignDeviceCategory.vehicle),
  BenignPhrase('android auto', BenignDeviceCategory.vehicle),
  BenignPhrase('infotainment', BenignDeviceCategory.vehicle),
];

/// Returns benign category when name matches a safe phrase (not when suspicious).
BenignDeviceCategory? matchBenignCategory(String? name) {
  final lower = name?.toLowerCase().trim();
  if (lower == null || lower.isEmpty) return null;

  BenignDeviceCategory? best;
  var bestLen = 0;
  for (final entry in benignPhrases) {
    if (_matchesPhrase(lower, entry.phrase) && entry.phrase.length > bestLen) {
      best = entry.category;
      bestLen = entry.phrase.length;
    }
  }
  return best;
}

bool _matchesPhrase(String lowerName, String phrase) {
  if (phrase.length <= 3) {
    return lowerName.contains(phrase);
  }
  final pattern = RegExp(
    r'(^|[^a-z0-9])' + RegExp.escape(phrase) + r'([^a-z0-9]|$)',
  );
  return pattern.hasMatch(lowerName) || lowerName == phrase;
}
