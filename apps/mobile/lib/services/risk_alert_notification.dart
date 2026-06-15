import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:unrecorded_core/unrecorded_core.dart';

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
    styleInformation: BigTextStyleInformation(
      AppCopy.possibleRiskNotificationExpanded,
      contentTitle: AppCopy.possibleRiskNotificationTitle,
      summaryText: AppCopy.possibleRiskNotificationBody,
    ),
  ),
  iOS: DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  ),
);

String get riskAlertTitle => AppCopy.possibleRiskNotificationTitle;

String get riskAlertBody => AppCopy.possibleRiskNotificationBody;

String get riskAlertPayload => notificationAlertPayload;
