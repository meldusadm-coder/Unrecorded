import '../features/scan/scan_state.dart';
import 'package:unrecorded_core/unrecorded_core.dart';

/// Android notification ID for the ongoing protection-status notification.
const protectionStatusNotificationId = 2;

/// Channel ID for the ongoing protection-status notification.
const protectionStatusChannelId = 'protection_active_status';

/// Whether [state] should show the ongoing protection-status notification.
bool shouldShowProtectionStatusNotification(ScanState state) {
  if (!state.protectionRequested || state.isBlocked) return false;
  return state.status == ScanStatus.starting ||
      state.status == ScanStatus.scanning ||
      state.status == ScanStatus.resting ||
      state.status == ScanStatus.confirmingRisk ||
      state.status == ScanStatus.possibleRiskDetected;
}

/// Privacy-safe body copy for the protection-status notification.
String protectionStatusBodyFor(ScanStatus status) {
  return switch (status) {
    ScanStatus.possibleRiskDetected =>
      'Possible risk nearby — tap to view details.',
    ScanStatus.resting ||
    ScanStatus.confirmingRisk =>
      'Checking nearby signals. Not proof of recording.',
    ScanStatus.starting =>
      'Watching for possible nearby recording-risk signals.',
    ScanStatus.scanning => AppCopy.protectionStatusNotificationScanningBody,
    _ => AppCopy.protectionStatusNotificationDefaultBody,
  };
}
