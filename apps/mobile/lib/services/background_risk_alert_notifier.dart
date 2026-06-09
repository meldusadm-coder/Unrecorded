import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:unrecorded_core/unrecorded_core.dart';

import 'notification_prefs.dart';
import 'notification_risk_threshold.dart';
import 'risk_alert_notification.dart';

/// Posts possible-risk alerts from the foreground-task isolate without
/// importing router or UI navigation code.
class BackgroundRiskAlertNotifier {
  BackgroundRiskAlertNotifier({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized || kIsWeb) return;

    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(
        settings: const InitializationSettings(android: android),
      );

      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          riskAlertChannelId,
          'Possible recording risk',
          description:
              'Alerts when Unrecorded detects a possible nearby recording risk.',
          importance: Importance.high,
        ),
      );

      _initialized = true;
    } catch (_) {
      // Plugin unavailable in tests without platform channels.
    }
  }

  /// Phase 2a proof: post a test possible-risk notification while minimised.
  Future<void> showTestAlert() async {
    await init();
    if (!_initialized) return;

    try {
      await _plugin.show(
        id: riskAlertNotificationId,
        title: riskAlertTitleFor(RiskLevel.high),
        body: riskAlertBody,
        notificationDetails: riskAlertNotificationDetails,
        payload: riskAlertPayload,
      );
      _log('test risk alert shown');
    } catch (e) {
      _log('test risk alert failed: $e');
    }
  }

  Future<void> showRiskAlertIfEnabled({required RiskLevel riskLevel}) async {
    final prefs = await NotificationPrefs.load();
    if (!prefs.riskNotificationsEnabled) {
      _log('risk alert skipped: user disabled');
      return;
    }
    if (!notificationThresholdMet(riskLevel, prefs.notificationRiskThreshold)) {
      _log('risk alert skipped: below threshold');
      return;
    }

    await init();
    if (!_initialized) return;

    try {
      await _plugin.show(
        id: riskAlertNotificationId,
        title: riskAlertTitleFor(riskLevel),
        body: riskAlertBody,
        notificationDetails: riskAlertNotificationDetails,
        payload: riskAlertPayload,
      );
      _log('risk alert shown: $riskLevel');
    } catch (e) {
      _log('risk alert show failed: $e');
    }
  }

  void _log(String message) {
    if (kDebugMode || kProfileMode) {
      debugPrint('[BackgroundRiskAlertNotifier] $message');
    }
  }
}
