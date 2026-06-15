import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_mobile/router.dart';
import 'package:unrecorded_mobile/services/risk_alert_notification.dart';

import 'support/certainty_language.dart';

void main() {
  test('notification payloads match routes', () {
    expect(notificationAlertPayload, 'alert-details');
    expect(notificationProtectionStatusPayload, 'protection-status');
    expect(notificationRecentRiskPayload, 'recent-risk');
    expect(alertDetailsRoute, '/alert-details');
    expect(recentRiskRoute, '/recent-risk');
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

  test('risk alert notification title is watch-safe and uncertainty-aware', () {
    expect(riskAlertTitle, AppCopy.possibleRiskNotificationTitle);
    expect(riskAlertTitle, isNotEmpty);
    expectNoCertaintyLanguage(riskAlertTitle);
    expect(riskAlertBody, AppCopy.possibleRiskNotificationBody);
    expectNoCertaintyLanguage(riskAlertBody);
  });
}
