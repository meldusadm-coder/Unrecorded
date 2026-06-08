import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_mobile/features/scan/scan_state.dart';
import 'package:unrecorded_mobile/router.dart';
import 'package:unrecorded_mobile/services/foreground_service_controller.dart';
import 'package:unrecorded_mobile/services/protection_status_notification.dart';
import 'package:unrecorded_mobile/services/risk_alert_notification.dart';

void main() {
  test('protection status and risk alert use different ids and channels', () {
    expect(protectionStatusNotificationId, isNot(riskAlertNotificationId));
    expect(protectionStatusChannelId, isNot(riskAlertChannelId));
    expect(backgroundProtectionFgsChannelId, isNot(protectionStatusChannelId));
    expect(backgroundProtectionFgsChannelId, isNot(riskAlertChannelId));
    expect(
      notificationProtectionStatusPayload,
      isNot(notificationAlertPayload),
    );
  });

  test('shouldShowProtectionStatusNotification for active protection states',
      () {
    for (final status in [
      ScanStatus.starting,
      ScanStatus.scanning,
      ScanStatus.resting,
      ScanStatus.confirmingRisk,
      ScanStatus.possibleRiskDetected,
    ]) {
      expect(
        shouldShowProtectionStatusNotification(
          ScanState(status: status, protectionRequested: true),
        ),
        isTrue,
        reason: status.name,
      );
    }
  });

  test('shouldShowProtectionStatusNotification false when paused or blocked',
      () {
    expect(
      shouldShowProtectionStatusNotification(
        const ScanState(status: ScanStatus.paused, protectionRequested: false),
      ),
      isFalse,
    );
    expect(
      shouldShowProtectionStatusNotification(
        const ScanState(
          status: ScanStatus.scanning,
          protectionRequested: true,
        ).copyWith(status: ScanStatus.permissionDenied),
      ),
      isFalse,
    );
    expect(
      shouldShowProtectionStatusNotification(
        const ScanState(status: ScanStatus.idle),
      ),
      isFalse,
    );
  });

  test('protectionStatusBodyFor uses privacy-safe copy', () {
    expect(
      protectionStatusBodyFor(ScanStatus.possibleRiskDetected),
      contains('Possible risk nearby'),
    );
    expect(
      protectionStatusBodyFor(ScanStatus.scanning),
      AppCopy.protectionStatusNotificationScanningBody,
    );
    expect(
      protectionStatusBodyFor(ScanStatus.resting),
      contains('Not proof of recording'),
    );
    for (final body in [
      protectionStatusBodyFor(ScanStatus.scanning),
      protectionStatusBodyFor(ScanStatus.resting),
      protectionStatusBodyFor(ScanStatus.possibleRiskDetected),
    ]) {
      expect(body.toLowerCase(), isNot(contains('recording detected')));
      expect(body.toLowerCase(), isNot(contains('confirmed')));
    }
  });
}
