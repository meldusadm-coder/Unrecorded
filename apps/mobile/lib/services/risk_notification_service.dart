import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

import '../router.dart';
import 'notification_prefs.dart';
import 'notification_risk_threshold.dart';

const _channelId = 'possible_recording_risk';
const _notificationId = 1;

/// Shows local (on-device) notifications for possible recording risk — no cloud.
class RiskNotificationService {
  RiskNotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  static final FlutterLocalNotificationsPlugin sharedPlugin =
      FlutterLocalNotificationsPlugin();

  bool get _platformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> init() async {
    if (_initialized || !_platformSupported) return;

    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      await _plugin.initialize(
        settings: const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              'Possible recording risk',
              description:
                  'Alerts when Unrecorded detects a possible nearby recording risk.',
              importance: Importance.high,
            ),
          );

      _initialized = true;
    } catch (_) {
      // Plugin unavailable (e.g. widget tests without platform channels).
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    if (response.payload == notificationAlertPayload) {
      navigateToAlertDetails();
    }
  }

  /// Opens alert details if the app was launched from a risk notification.
  Future<void> handleNotificationLaunch() async {
    if (!_platformSupported) return;

    await init();
    if (!_initialized) return;

    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return;
      final payload = details?.notificationResponse?.payload;
      if (payload == notificationAlertPayload) {
        navigateToAlertDetails();
      }
    } catch (_) {}
  }

  /// Requests OS permission when the user enables notifications.
  Future<bool> requestPermissionIfNeeded() async {
    if (!_platformSupported) return false;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    if (granted != null) return granted;

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final iosGranted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return iosGranted ?? true;
  }

  Future<void> showRiskAlertIfEnabled({required RiskLevel riskLevel}) async {
    if (!_platformSupported) return;

    final prefs = await NotificationPrefs.load();
    if (!prefs.riskNotificationsEnabled) return;
    if (!notificationThresholdMet(
      riskLevel,
      prefs.notificationRiskThreshold,
    )) {
      return;
    }

    await init();
    if (!_initialized) return;

    final allowed = await requestPermissionIfNeeded();
    if (!allowed) return;

    final levelLabel = RiskBadge.labelFor(riskLevel);
    final title = '$levelLabel — ${AppCopy.possibleRiskTitle}';

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Possible recording risk',
        channelDescription:
            'Alerts when Unrecorded detects a possible nearby recording risk.',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      await _plugin.show(
        id: _notificationId,
        title: title,
        body: AppCopy.possibleRiskBody,
        notificationDetails: details,
        payload: notificationAlertPayload,
      );
    } catch (_) {}
  }

  Future<void> cancelRiskAlert() async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: _notificationId);
    } catch (_) {}
  }
}

final riskNotificationServiceProvider =
    Provider<RiskNotificationService>((ref) {
  return RiskNotificationService(RiskNotificationService.sharedPlugin);
});
