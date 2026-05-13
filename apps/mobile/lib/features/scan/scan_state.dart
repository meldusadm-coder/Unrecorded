import 'package:unrecorded_core/unrecorded_core.dart';

enum ScanStatus { idle, scanning, paused, error }

class ScanState {
  final ScanStatus status;
  final List<DetectedSignal> signals;
  final RiskLevel riskLevel;
  final int score;
  final List<String> reasons;

  const ScanState({
    this.status = ScanStatus.idle,
    this.signals = const [],
    this.riskLevel = RiskLevel.low,
    this.score = 0,
    this.reasons = const [],
  });

  ScanState copyWith({
    ScanStatus? status,
    List<DetectedSignal>? signals,
    RiskLevel? riskLevel,
    int? score,
    List<String>? reasons,
  }) {
    return ScanState(
      status: status ?? this.status,
      signals: signals ?? this.signals,
      riskLevel: riskLevel ?? this.riskLevel,
      score: score ?? this.score,
      reasons: reasons ?? this.reasons,
    );
  }
}
