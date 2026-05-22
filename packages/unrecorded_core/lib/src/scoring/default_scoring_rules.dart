import '../models/detected_signal.dart';
import 'scoring_rule.dart';

/// Matches device names commonly associated with smart glasses or
/// wearable recording devices.
class SuspiciousNameRule extends ScoringRule {
  /// Keywords shared with [DeviceSignalClassifier] for wearable-like names.
  static const keywords = [
    'ray-ban',
    'meta',
    'smart glasses',
    'spectacles',
    'camera',
    'glasses',
    'snap',
    'stories',
    'even realities',
    'focals',
    'vuzix',
    'xreal',
    'nreal',
    'inmo',
    'tcl',
    'solos',
    'optic',
  ];

  @override
  int score(DetectedSignal signal) {
    final name = signal.displayName?.toLowerCase();
    if (name == null) return 0;
    for (final kw in keywords) {
      if (name.contains(kw)) return 40;
    }
    return 0;
  }

  @override
  String? reason(DetectedSignal signal) {
    if (score(signal) > 0) {
      return 'A nearby signal has a name commonly associated with '
          'smart glasses or a wearable recording device.';
    }
    return null;
  }
}

/// Awards points when a signal is very strong (close proximity).
class StrongSignalRule extends ScoringRule {
  static const _strongThreshold = -50;

  @override
  int score(DetectedSignal signal) {
    final rssi = signal.rssi;
    if (rssi == null) return 0;
    if (rssi >= _strongThreshold) return 15;
    return 0;
  }

  @override
  String? reason(DetectedSignal signal) {
    if (score(signal) > 0) {
      return 'A signal is unusually strong, suggesting the device '
          'may be very close.';
    }
    return null;
  }
}

/// Awards extra points when the same suspicious signal appears in multiple
/// consecutive snapshots (approximated here by being connectable, which
/// suggests sustained proximity rather than a drive-by).
class ConnectableDeviceRule extends ScoringRule {
  @override
  int score(DetectedSignal signal) {
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
