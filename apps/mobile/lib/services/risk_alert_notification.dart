import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

import 'notification_payloads.dart';

/// Android channel and notification ID for possible-risk alerts.
const riskAlertChannelId = 'possible_recording_risk';
const riskAlertNotificationId = 1;

/// Router-free notification details for possible-risk alerts.
const NotificationDetails riskAlertNotificationDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    riskAlertChannelId,
    'Possible recording risk',
    channelDescription:
        'Alerts when Unrecorded detects a possible nearby recording risk.',
    importance: Importance.high,
    priority: Priority.high,
    visibility: NotificationVisibility.public,
  ),
  iOS: DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  ),
);

String riskAlertTitleFor(RiskLevel riskLevel) {
  final levelLabel = RiskBadge.labelFor(riskLevel);
  return '$levelLabel — ${AppCopy.possibleRiskTitle}';
}

String get riskAlertBody => AppCopy.possibleRiskBody;

String get riskAlertPayload => notificationAlertPayload;
