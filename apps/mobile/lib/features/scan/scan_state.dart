import 'package:unrecorded_core/unrecorded_core.dart';

/// User-visible scan lifecycle states.
enum ScanStatus {
  idle,
  starting,
  scanning,
  possibleRiskDetected,
  paused,
  error,
  permissionRequired,
}

class ScanState {
  final ScanStatus status;
  final List<DetectedSignal> signals;
  final RiskLevel riskLevel;
  final int score;
  final List<String> reasons;
  final String? statusMessage;
  final DateTime? lastCheckedAt;
  final bool protectionEnabled;

  const ScanState({
    this.status = ScanStatus.idle,
    this.signals = const [],
    this.riskLevel = RiskLevel.low,
    this.score = 0,
    this.reasons = const [],
    this.statusMessage,
    this.lastCheckedAt,
    this.protectionEnabled = false,
  });

  bool get isProtectionActive =>
      protectionEnabled &&
      (status == ScanStatus.scanning ||
          status == ScanStatus.possibleRiskDetected ||
          status == ScanStatus.starting);

  bool get hasElevatedRisk =>
      riskLevel == RiskLevel.medium || riskLevel == RiskLevel.high;

  ScanState copyWith({
    ScanStatus? status,
    List<DetectedSignal>? signals,
    RiskLevel? riskLevel,
    int? score,
    List<String>? reasons,
    String? statusMessage,
    DateTime? lastCheckedAt,
    bool? protectionEnabled,
    bool clearStatusMessage = false,
  }) {
    return ScanState(
      status: status ?? this.status,
      signals: signals ?? this.signals,
      riskLevel: riskLevel ?? this.riskLevel,
      score: score ?? this.score,
      reasons: reasons ?? this.reasons,
      statusMessage:
          clearStatusMessage ? null : (statusMessage ?? this.statusMessage),
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      protectionEnabled: protectionEnabled ?? this.protectionEnabled,
    );
  }
}
