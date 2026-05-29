import '../detection/signature_matcher.dart';
import '../models/detected_signal.dart';
import 'scoring_rule.dart';

/// Matches signals against the local detection signature catalogue.
class SignatureMatchRule extends ScoringRule {
  SignatureMatchRule({SignatureMatcher? matcher})
      : _matcher = matcher ?? const SignatureMatcher();

  final SignatureMatcher _matcher;

  /// Whether [signal] matches any catalogue signature.
  bool matches(DetectedSignal signal) => _matcher.hasMatch(signal);

  SignatureMatch? matchFor(DetectedSignal signal) => _matcher.bestMatch(signal);

  @override
  int score(DetectedSignal signal) => matchFor(signal)?.score ?? 0;

  @override
  String? reason(DetectedSignal signal) => matchFor(signal)?.explanation;
}

/// Awards points when a signal is very strong (close proximity).
class StrongSignalRule extends ScoringRule {
  StrongSignalRule({SignatureMatcher? matcher})
      : _matcher = matcher ?? const SignatureMatcher();

  final SignatureMatcher _matcher;

  static const _strongThreshold = -55;
  static const _moderateThreshold = -68;

  @override
  int score(DetectedSignal signal) {
    if (!_matcher.hasMatch(signal)) return 0;
    final rssi = signal.rssi;
    if (rssi == null) return 0;
    if (rssi >= _strongThreshold) return 10;
    if (rssi >= _moderateThreshold) return 5;
    return 0;
  }

  @override
  String? reason(DetectedSignal signal) {
    final pts = score(signal);
    if (pts >= 10) {
      return 'A strong nearby signal was seen. Signal strength is only a rough '
          'proximity indicator and not precise distance.';
    }
    if (pts == 5) {
      return 'A moderate nearby signal was seen. Signal strength is only a rough '
          'proximity indicator.';
    }
    return null;
  }
}

/// Awards extra points when a matched signal is connectable, which may
/// suggest sustained proximity rather than a drive-by advertisement.
class ConnectableDeviceRule extends ScoringRule {
  ConnectableDeviceRule({SignatureMatcher? matcher})
      : _matcher = matcher ?? const SignatureMatcher();

  final SignatureMatcher _matcher;

  @override
  int score(DetectedSignal signal) {
    if (!_matcher.hasMatch(signal)) return 0;
    return signal.isConnectable ? 10 : 0;
  }

  @override
  String? reason(DetectedSignal signal) {
    if (score(signal) > 0) {
      return 'The device is actively connectable, which may indicate '
          'it is in use nearby.';
    }
    return null;
  }
}
