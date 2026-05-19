import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_mobile/services/notification_risk_threshold.dart';

void main() {
  test('highOnly notifies for high risk only', () {
    expect(
      notificationThresholdMet(
        RiskLevel.high,
        NotificationRiskThreshold.highOnly,
      ),
      isTrue,
    );
    expect(
      notificationThresholdMet(
        RiskLevel.medium,
        NotificationRiskThreshold.highOnly,
      ),
      isFalse,
    );
  });

  test('mediumAndHigh notifies for medium and high', () {
    expect(
      notificationThresholdMet(
        RiskLevel.medium,
        NotificationRiskThreshold.mediumAndHigh,
      ),
      isTrue,
    );
    expect(
      notificationThresholdMet(
        RiskLevel.low,
        NotificationRiskThreshold.mediumAndHigh,
      ),
      isFalse,
    );
  });
}
