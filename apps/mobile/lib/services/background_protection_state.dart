import 'background_protection_snapshot.dart';

/// UI-facing state for background protection (compatibility shim).
class BackgroundProtectionState {
  const BackgroundProtectionState({
    this.enabled = false,
    this.serviceRunning = false,
    this.stoppedReason = BackgroundProtectionStoppedReason.none,
    this.lastFailureMessage,
  });

  final bool enabled;
  final bool serviceRunning;
  final BackgroundProtectionStoppedReason stoppedReason;
  final String? lastFailureMessage;

  bool get ownsScanning => serviceRunning;

  bool get showsStoppedByAndroidBanner =>
      enabled &&
      !serviceRunning &&
      stoppedReason == BackgroundProtectionStoppedReason.stoppedByAndroid;

  BackgroundProtectionState copyWith({
    bool? enabled,
    bool? serviceRunning,
    BackgroundProtectionStoppedReason? stoppedReason,
    String? lastFailureMessage,
    bool clearLastFailureMessage = false,
  }) {
    return BackgroundProtectionState(
      enabled: enabled ?? this.enabled,
      serviceRunning: serviceRunning ?? this.serviceRunning,
      stoppedReason: stoppedReason ?? this.stoppedReason,
      lastFailureMessage: clearLastFailureMessage
          ? null
          : (lastFailureMessage ?? this.lastFailureMessage),
    );
  }
}
