import 'detected_signal.dart';

/// A point-in-time snapshot of all detected signals during one scan cycle.
class ScanSnapshot {
  /// All signals observed in this scan cycle.
  final List<DetectedSignal> signals;

  /// When this snapshot was captured.
  final DateTime capturedAt;

  const ScanSnapshot({
    required this.signals,
    required this.capturedAt,
  });

  /// True when no signals were detected.
  bool get isEmpty => signals.isEmpty;

  /// Number of signals in this snapshot.
  int get count => signals.length;
}
