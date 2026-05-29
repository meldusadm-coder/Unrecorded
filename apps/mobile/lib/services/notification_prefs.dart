import 'package:shared_preferences/shared_preferences.dart';

import 'notification_risk_threshold.dart';

const _keyRiskNotificationsEnabled = 'risk_notifications_enabled';
const _keyNotificationRiskThreshold = 'notification_risk_threshold';

/// User preference for local alerts when possible recording risk is detected.
class NotificationPrefs {
  NotificationPrefs(this._prefs);

  final SharedPreferences _prefs;

  static Future<NotificationPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationPrefs(prefs);
  }

  /// On by default when the user enables risk alerts in settings.
  bool get riskNotificationsEnabled =>
      _prefs.getBool(_keyRiskNotificationsEnabled) ?? true;

  Future<void> setRiskNotificationsEnabled(bool value) async {
    await _prefs.setBool(_keyRiskNotificationsEnabled, value);
  }

  NotificationRiskThreshold get notificationRiskThreshold =>
      NotificationRiskThresholdStorage.fromStorage(
        _prefs.getString(_keyNotificationRiskThreshold),
      );

  Future<void> setNotificationRiskThreshold(
    NotificationRiskThreshold value,
  ) async {
    await _prefs.setString(_keyNotificationRiskThreshold, value.storageKey);
  }
}
