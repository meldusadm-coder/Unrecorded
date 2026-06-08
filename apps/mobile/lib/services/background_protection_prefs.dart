import 'package:shared_preferences/shared_preferences.dart';

const _keyBackgroundProtectionEnabled = 'background_protection_enabled';
const _keyExplicitlyStopped = 'background_protection_explicitly_stopped';

/// Persists user intent for Android background protection (off by default).
class BackgroundProtectionPrefs {
  BackgroundProtectionPrefs(this._prefs);

  final SharedPreferences _prefs;

  static Future<BackgroundProtectionPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    return BackgroundProtectionPrefs(prefs);
  }

  bool get backgroundProtectionEnabled =>
      _prefs.getBool(_keyBackgroundProtectionEnabled) ?? false;

  bool get explicitlyStopped => _prefs.getBool(_keyExplicitlyStopped) ?? false;

  Future<void> setBackgroundProtectionEnabled(bool value) async {
    await _prefs.setBool(_keyBackgroundProtectionEnabled, value);
  }

  Future<void> setExplicitlyStopped(bool value) async {
    await _prefs.setBool(_keyExplicitlyStopped, value);
  }

  /// Called from the notification Stop action before stopping the service.
  Future<void> recordExplicitStop() async {
    await setExplicitlyStopped(true);
    await setBackgroundProtectionEnabled(false);
  }

  Future<void> clearExplicitlyStopped() async {
    await setExplicitlyStopped(false);
  }
}
