import '../detection/signature_matcher.dart';
import '../models/detected_signal.dart';
import '../scoring/risk_scoring_engine.dart';
import 'device_signal_category.dart';

/// Result of classifying a single [DetectedSignal] for display and filtering.
class ClassifiedSignal {
  const ClassifiedSignal({
    required this.signal,
    required this.category,
    required this.typeLabel,
    this.vendorHint,
    this.relevanceScore = 0,
  });

  final DetectedSignal signal;
  final DeviceSignalCategory category;
  final String typeLabel;

  /// Optional hint from a local MAC prefix map (not proof of vendor).
  final String? vendorHint;

  /// Higher = more relevant for alert-details ranking.
  final int relevanceScore;
}

/// Local, catalogue-based classification — no network lookups.
class DeviceSignalClassifier {
  DeviceSignalClassifier({
    RiskScoringEngine? scoringEngine,
    SignatureMatcher? matcher,
  })  : _matcher = matcher ?? const SignatureMatcher(),
        _scoringEngine = scoringEngine ??
            RiskScoringEngine(matcher: matcher ?? const SignatureMatcher());

  final SignatureMatcher _matcher;
  final RiskScoringEngine _scoringEngine;

  ClassifiedSignal classify(DetectedSignal signal) {
    final vendorHint = _matcher.vendorHintFromId(signal.id);

    if (SignatureMatcher.isBenignName(signal.displayName)) {
      return ClassifiedSignal(
        signal: signal,
        category: DeviceSignalCategory.likelyBenign,
        typeLabel: 'Headphones or speaker (unlikely recording)',
        vendorHint: vendorHint,
      );
    }

    final match = _matcher.bestMatch(signal);
    if (match != null) {
      return ClassifiedSignal(
        signal: signal,
        category: DeviceSignalCategory.possibleRecordingWearable,
        typeLabel:
            'Possible smart glasses / wearable (${match.signature.brandFamily})',
        vendorHint: vendorHint,
        relevanceScore: _relevanceScore(signal),
      );
    }

    if (vendorHint != null) {
      return ClassifiedSignal(
        signal: signal,
        category: DeviceSignalCategory.possibleRecordingWearable,
        typeLabel: 'Possible smart glasses / wearable',
        vendorHint: vendorHint,
        relevanceScore: _relevanceScore(signal) + 5,
      );
    }

    return ClassifiedSignal(
      signal: signal,
      category: DeviceSignalCategory.unknown,
      typeLabel: 'Unknown nearby device',
      vendorHint: vendorHint,
      relevanceScore: _relevanceScore(signal),
    );
  }

  /// Top signals to show on alert details (recording-relevant first).
  List<ClassifiedSignal> topAlertSignals(
    List<DetectedSignal> signals, {
    int max = 3,
  }) {
    final classified = signals.map(classify).toList()
      ..removeWhere((c) => c.category == DeviceSignalCategory.likelyBenign);
    classified.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
    return classified.take(max).toList();
  }

  List<ClassifiedSignal> classifyAll(List<DetectedSignal> signals) =>
      signals.map(classify).toList();

  int _relevanceScore(DetectedSignal signal) {
    var total = 0;
    for (final rule in _scoringEngine.rules) {
      total += rule.score(signal);
    }
    return total;
  }

  /// User-facing label for [signal.id] line on alert details.
  static String idLabel(String id) => SignatureMatcher.normalizeMac(id) != null
      ? 'Bluetooth address'
      : 'Device ID';

  static String formatId(String id) {
    final mac = SignatureMatcher.normalizeMac(id);
    if (mac == null || mac.length < 12) return id;
    final pairs = <String>[];
    for (var i = 0; i < 12; i += 2) {
      pairs.add(mac.substring(i, i + 2));
    }
    return pairs.join(':');
  }
}
