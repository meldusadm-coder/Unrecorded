import '../features/scan/scan_state.dart';
import 'notification_payloads.dart';
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

/// Privacy-safe body copy for the background foreground-service notification.
///
/// Matches [protectionStatusBodyFor] except while actively scanning in
/// background mode, where the "keep app open" message would be misleading.
String backgroundProtectionStatusBodyFor(ScanStatus status) {
  if (status == ScanStatus.scanning) {
    return 'Checking nearby signals. Not proof of recording.';
  }
  return protectionStatusBodyFor(status);
}

/// Body and tap payload for the ongoing protection-status notification.
class ProtectionStatusNotificationContent {
  const ProtectionStatusNotificationContent({
    required this.body,
    required this.payload,
  });

  final String body;
  final String payload;
}

/// Chooses protection-status notification body and tap payload.
ProtectionStatusNotificationContent protectionStatusNotificationContentFor({
  required ScanStatus status,
  required bool recentRiskVisible,
}) {
  if (status == ScanStatus.possibleRiskDetected) {
    return const ProtectionStatusNotificationContent(
      body: 'Possible risk nearby — tap to view details.',
      payload: notificationAlertPayload,
    );
  }
  if (recentRiskVisible) {
    return const ProtectionStatusNotificationContent(
      body: AppCopy.protectionStatusNotificationRecentRiskBody,
      payload: notificationRecentRiskPayload,
    );
  }
  return ProtectionStatusNotificationContent(
    body: protectionStatusBodyFor(status),
    payload: notificationProtectionStatusPayload,
  );
}
