import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_mobile/router.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

void main() {
  test('notification payloads match routes', () {
    expect(notificationAlertPayload, 'alert-details');
    expect(notificationProtectionStatusPayload, 'protection-status');
    expect(alertDetailsRoute, '/alert-details');
    expect(alertInfoRoute, '/alert-info');
  });

  test('protection status notification title is uncertainty-aware', () {
    expect(
      AppCopy.protectionStatusNotificationTitle,
      contains('protection is active'),
    );
    expect(
      AppCopy.protectionStatusNotificationTitle.toLowerCase(),
      isNot(contains('recording detected')),
    );
  });

  test('notification title includes risk level label', () {
    expect(
      '${RiskBadge.labelFor(RiskLevel.high)} — ${AppCopy.possibleRiskTitle}',
      'High risk — Possible recording risk nearby',
    );
    expect(
      '${RiskBadge.labelFor(RiskLevel.medium)} — ${AppCopy.possibleRiskTitle}',
      contains('Medium risk'),
    );
  });
}
