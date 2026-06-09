import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import '../features/scan/scan_state.dart';
import '../router.dart';
import 'notification_prefs.dart';
import 'notification_risk_threshold.dart';
import 'protection_status_notification.dart';
import 'risk_alert_notification.dart';

/// Shows local (on-device) notifications for protection status and possible risk.
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

      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          protectionStatusChannelId,
          'Protection status',
          description:
              'Shows when Unrecorded protection is active while the app is running.',
          importance: Importance.defaultImportance,
        ),
      );

      _initialized = true;
    } catch (_) {
      // Plugin unavailable (e.g. widget tests without platform channels).
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    switch (response.payload) {
      case notificationAlertPayload:
        navigateToAlertDetails();
      case notificationProtectionStatusPayload:
        navigateToProtectionScreen();
      default:
        break;
    }
  }

  /// Opens the correct screen if the app was launched from a notification.
  Future<void> handleNotificationLaunch() async {
    if (!_platformSupported) return;

    await init();
    if (!_initialized) return;

    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return;
      final payload = details?.notificationResponse?.payload;
      switch (payload) {
        case notificationAlertPayload:
          navigateToAlertDetails();
        case notificationProtectionStatusPayload:
          navigateToProtectionScreen();
        default:
          break;
      }
    } catch (_) {}
  }

  /// Whether OS-level notifications are enabled for this app.
  ///
  /// On Android 13+, this reflects POST_NOTIFICATIONS grant and the system
  /// notifications toggle. On older Android and iOS, uses platform checks.
  Future<bool> notificationsOsEnabled() async {
    if (!_platformSupported) return false;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final androidEnabled = await android?.areNotificationsEnabled();
    if (androidEnabled != null) return androidEnabled;

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final settings = await ios.checkPermissions();
      return settings?.isEnabled ?? false;
    }

    return true;
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
    if (iosGranted != null) return iosGranted;

    return notificationsOsEnabled();
  }

  Future<void> syncProtectionStatusNotification(ScanState state) async {
    if (!_platformSupported) return;

    if (!shouldShowProtectionStatusNotification(state)) {
      await cancelProtectionStatusNotification();
      return;
    }

    if (!await notificationsOsEnabled()) {
      _logDebug('protection status skipped: OS notifications disabled');
      await cancelProtectionStatusNotification();
      return;
    }

    await init();
    if (!_initialized) return;

    final body = protectionStatusBodyFor(state.status);
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        protectionStatusChannelId,
        'Protection status',
        channelDescription:
            'Shows when Unrecorded protection is active while the app is running.',
        importance: Importance.defaultImportance,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.status,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      ),
    );

    try {
      await _plugin.show(
        id: protectionStatusNotificationId,
        title: AppCopy.protectionStatusNotificationTitle,
        body: body,
        notificationDetails: details,
        payload: notificationProtectionStatusPayload,
      );
      _logDebug('protection status shown: ${state.status.name}');
    } catch (e) {
      _logDebug('protection status show failed: $e');
    }
  }

  Future<void> cancelProtectionStatusNotification() async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: protectionStatusNotificationId);
      _logDebug('protection status cancelled');
    } catch (_) {}
  }

  Future<void> showRiskAlertIfEnabled({required RiskLevel riskLevel}) async {
    if (!_platformSupported) return;

    final prefs = await NotificationPrefs.load();
    if (!prefs.riskNotificationsEnabled) {
      _logDebug('risk alert skipped: user disabled risk alerts');
      return;
    }
    if (!notificationThresholdMet(
      riskLevel,
      prefs.notificationRiskThreshold,
    )) {
      _logDebug('risk alert skipped: below threshold ($riskLevel)');
      return;
    }

    await init();
    if (!_initialized) return;

    if (!await notificationsOsEnabled()) {
      _logDebug('risk alert skipped: OS notifications disabled');
      return;
    }

    try {
      await _plugin.show(
        id: riskAlertNotificationId,
        title: riskAlertTitleFor(riskLevel),
        body: riskAlertBody,
        notificationDetails: riskAlertNotificationDetails,
        payload: riskAlertPayload,
      );
      _logDebug('risk alert shown: $riskLevel');
    } catch (e) {
      _logDebug('risk alert show failed: $e');
    }
  }

  Future<void> cancelRiskAlert() async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: riskAlertNotificationId);
      _logDebug('risk alert cancelled');
    } catch (_) {}
  }

  void _logDebug(String message) {
    if (kDebugMode || kProfileMode) {
      debugPrint('[RiskNotificationService] $message');
    }
  }
}

final riskNotificationServiceProvider =
    Provider<RiskNotificationService>((ref) {
  return RiskNotificationService(RiskNotificationService.sharedPlugin);
});
