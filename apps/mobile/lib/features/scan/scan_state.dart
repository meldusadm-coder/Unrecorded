import 'package:unrecorded_core/unrecorded_core.dart';

import 'signal_ui_model.dart';

/// User-visible scan lifecycle states.
enum ScanStatus {
  idle,
  starting,
  scanning,
  resting,
  confirmingRisk,
  possibleRiskDetected,
  paused,
  permissionDenied,
  permissionPermanentlyDenied,
  bluetoothOff,
  bluetoothUnsupported,
  error,
}

class ScanState {
  final ScanStatus status;
  final RiskLevel riskLevel;
  final int score;
  final List<String> reasons;
  final List<SignalUiModel> possibleRiskSignals;
  final List<SignalUiModel> otherNearbySignals;
  final String? statusMessage;
  final DateTime? lastCheckedAt;
  final DateTime? nextScanAt;
  final bool protectionRequested;
  final bool isDemoMode;
  final bool alertDismissed;

  const ScanState({
    this.status = ScanStatus.idle,
    this.riskLevel = RiskLevel.low,
    this.score = 0,
    this.reasons = const [],
    this.possibleRiskSignals = const [],
    this.otherNearbySignals = const [],
    this.statusMessage,
    this.lastCheckedAt,
    this.nextScanAt,
    this.protectionRequested = false,
    this.isDemoMode = false,
    this.alertDismissed = false,
  });

  bool get canStart =>
      status == ScanStatus.idle || status == ScanStatus.paused || isBlocked;

  bool get canPause =>
      protectionRequested &&
      (isActiveOrResting || status == ScanStatus.starting);

  bool get isBlocked =>
      status == ScanStatus.permissionDenied ||
      status == ScanStatus.permissionPermanentlyDenied ||
      status == ScanStatus.bluetoothOff ||
      status == ScanStatus.bluetoothUnsupported;

  bool get isActiveOrResting =>
      status == ScanStatus.scanning ||
      status == ScanStatus.resting ||
      status == ScanStatus.confirmingRisk ||
      status == ScanStatus.possibleRiskDetected ||
      status == ScanStatus.starting;

  bool get protectionActive => isActiveOrResting && !isBlocked;

  bool get showsRiskAlert =>
      status == ScanStatus.possibleRiskDetected && !alertDismissed;

  bool get hasElevatedRisk =>
      riskLevel == RiskLevel.medium || riskLevel == RiskLevel.high;

  ScanState copyWith({
    ScanStatus? status,
    RiskLevel? riskLevel,
    int? score,
    List<String>? reasons,
    List<SignalUiModel>? possibleRiskSignals,
    List<SignalUiModel>? otherNearbySignals,
    String? statusMessage,
    DateTime? lastCheckedAt,
    DateTime? nextScanAt,
    bool? protectionRequested,
    bool? isDemoMode,
    bool? alertDismissed,
    bool clearStatusMessage = false,
    bool clearNextScanAt = false,
  }) {
    return ScanState(
      status: status ?? this.status,
      riskLevel: riskLevel ?? this.riskLevel,
      score: score ?? this.score,
      reasons: reasons ?? this.reasons,
      possibleRiskSignals: possibleRiskSignals ?? this.possibleRiskSignals,
      otherNearbySignals: otherNearbySignals ?? this.otherNearbySignals,
      statusMessage:
          clearStatusMessage ? null : (statusMessage ?? this.statusMessage),
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      nextScanAt: clearNextScanAt ? null : (nextScanAt ?? this.nextScanAt),
      protectionRequested: protectionRequested ?? this.protectionRequested,
      isDemoMode: isDemoMode ?? this.isDemoMode,
      alertDismissed: alertDismissed ?? this.alertDismissed,
    );
  }
}
