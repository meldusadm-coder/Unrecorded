import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_mobile/router.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

void main() {
  test('notification payload matches alert route', () {
    expect(notificationAlertPayload, 'alert-info');
    expect(alertInfoRoute, '/alert-info');
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
