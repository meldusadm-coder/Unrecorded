import '../models/detected_signal.dart';
import '../scoring/default_scoring_rules.dart';
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

/// Local, name- and prefix-based classification — no network lookups.
class DeviceSignalClassifier {
  DeviceSignalClassifier({
    RiskScoringEngine? scoringEngine,
  }) : _scoringEngine = scoringEngine ?? RiskScoringEngine();

  final RiskScoringEngine _scoringEngine;

  static const _benignKeywords = [
    'earbud',
    'earbuds',
    'airpod',
    'airpods',
    'headphone',
    'headphones',
    'beats',
    'jbl',
    'bose',
    'sony wh',
    'speaker',
    'soundbar',
    'sound bar',
    'keyboard',
    'mouse',
    'trackpad',
    'television',
    ' smart tv',
    ' roku',
    'chromecast',
    'fitbit',
    'garmin',
    'whoop',
  ];

  /// Longest-prefix match for common wearable-recording vendor OUIs (hex, no separators).
  static const Map<String, String> _ouiVendorHints = {
    '000b9a': 'May be Meta / Ray-Ban (address prefix hint)',
    'e45f01': 'May be Meta (address prefix hint)',
    'acbc32': 'May be Snap / Spectacles (address prefix hint)',
    'f4a739': 'May be Snap (address prefix hint)',
  };

  ClassifiedSignal classify(DetectedSignal signal) {
    final name = signal.displayName?.toLowerCase();
    final vendorHint = _vendorHintFromId(signal.id);

    if (name != null) {
      for (final kw in _benignKeywords) {
        if (name.contains(kw)) {
          return ClassifiedSignal(
            signal: signal,
            category: DeviceSignalCategory.likelyBenign,
            typeLabel: 'Headphones or speaker (unlikely recording)',
            vendorHint: vendorHint,
          );
        }
      }
      for (final kw in SuspiciousNameRule.keywords) {
        if (name.contains(kw)) {
          return ClassifiedSignal(
            signal: signal,
            category: DeviceSignalCategory.possibleRecordingWearable,
            typeLabel: 'Possible smart glasses / wearable',
            vendorHint: vendorHint,
            relevanceScore: _relevanceScore(signal),
          );
        }
      }
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

  String? _vendorHintFromId(String id) {
    final normalized = _normalizeMac(id);
    if (normalized == null || normalized.length < 6) return null;
    String? best;
    var bestLen = 0;
    for (final entry in _ouiVendorHints.entries) {
      if (normalized.startsWith(entry.key) && entry.key.length > bestLen) {
        best = entry.value;
        bestLen = entry.key.length;
      }
    }
    return best;
  }

  /// Returns lowercase hex without separators if [id] looks like a MAC/BLE address.
  static String? _normalizeMac(String id) {
    final trimmed = id.trim().toLowerCase();
    if (RegExp(r'^([0-9a-f]{2}:){5}[0-9a-f]{2}$').hasMatch(trimmed)) {
      return trimmed.replaceAll(':', '');
    }
    if (RegExp(r'^([0-9a-f]{2}-){5}[0-9a-f]{2}$').hasMatch(trimmed)) {
      return trimmed.replaceAll('-', '');
    }
    final hexOnly = trimmed.replaceAll(RegExp(r'[^0-9a-f]'), '');
    if (hexOnly.length >= 12 && RegExp(r'^[0-9a-f]+$').hasMatch(hexOnly)) {
      return hexOnly.substring(0, 12);
    }
    return null;
  }

  /// User-facing label for [signal.id] line on alert details.
  static String idLabel(String id) =>
      _normalizeMac(id) != null ? 'Bluetooth address' : 'Device ID';

  static String formatId(String id) {
    final mac = _normalizeMac(id);
    if (mac == null || mac.length < 12) return id;
    final pairs = <String>[];
    for (var i = 0; i < 12; i += 2) {
      pairs.add(mac.substring(i, i + 2));
    }
    return pairs.join(':');
  }
}
