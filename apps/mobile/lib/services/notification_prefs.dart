import 'package:shared_preferences/shared_preferences.dart';

const _keyRiskNotificationsEnabled = 'risk_notifications_enabled';

/// User preference for local alerts when possible recording risk is detected.
class NotificationPrefs {
  NotificationPrefs(this._prefs);

  final SharedPreferences _prefs;

  static Future<NotificationPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationPrefs(prefs);
  }

  /// On by default so protection can warn when the app is in the background.
  bool get riskNotificationsEnabled =>
      _prefs.getBool(_keyRiskNotificationsEnabled) ?? true;

  Future<void> setRiskNotificationsEnabled(bool value) async {
    await _prefs.setBool(_keyRiskNotificationsEnabled, value);
  }
}
