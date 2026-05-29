import '../detection/detection_assessment.dart';
import '../detection/detection_engine.dart';
import '../detection/signature_matcher.dart';
import '../models/detected_signal.dart';
import '../session/scan_session.dart';
import 'device_signal_category.dart';

/// Result of classifying a single signal for display and filtering.
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

  final String? vendorHint;
  final int relevanceScore;
}

/// Local, catalogue-based classification — delegates to [DetectionEngine].
class DeviceSignalClassifier {
  DeviceSignalClassifier({
    DetectionEngine? detectionEngine,
    SignatureMatcher? matcher,
  })
      : _engine = detectionEngine ?? DetectionEngine(matcher: matcher),
        _matcher = matcher ?? const SignatureMatcher();

  final DetectionEngine _engine;
  final SignatureMatcher _matcher;

  ClassifiedSignal classify(DetectedSignal signal) {
    final session = ScanSession();
    session.observe(signal);
    final assessment =
        _engine.assessAll(session.activeSignals(signal.seenAt)).single;
    final vendorHint = _matcher.vendorHintFromId(signal.id);

    return ClassifiedSignal(
      signal: signal,
      category: assessment.category,
      typeLabel: _typeLabel(assessment),
      vendorHint: vendorHint,
      relevanceScore: assessment.contributesToRisk ? 50 : 0,
    );
  }

  String _typeLabel(DetectionAssessment assessment) {
    final match = assessment.matchedSignature;
    if (match != null) {
      return 'Possible smart glasses / wearable (${match.brandFamily})';
    }
    if (assessment.category == DeviceSignalCategory.possibleRecordingWearable) {
      return 'Possible smart glasses / wearable';
    }
    if (assessment.category == DeviceSignalCategory.likelyBenign ||
        assessment.category == DeviceSignalCategory.likelyAudio) {
      return 'Headphones or speaker (unlikely recording)';
    }
    return assessment.category.displayLabel;
  }

  List<ClassifiedSignal> topAlertSignals(
    List<DetectedSignal> signals, {
    int max = 3,
  }) {
    final classified = signals.map(classify).toList()
      ..removeWhere(
        (c) => c.category != DeviceSignalCategory.possibleRecordingWearable,
      );
    classified.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
    return classified.take(max).toList();
  }

  List<ClassifiedSignal> classifyAll(List<DetectedSignal> signals) =>
      signals.map(classify).toList();

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
