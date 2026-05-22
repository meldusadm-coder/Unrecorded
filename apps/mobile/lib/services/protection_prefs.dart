import 'package:shared_preferences/shared_preferences.dart';

const _keyProtectionEnabled = 'protection_enabled';

/// Persists whether the user wants protection (continuous scanning) on.
class ProtectionPrefs {
  ProtectionPrefs(this._prefs);

  final SharedPreferences _prefs;

  static Future<ProtectionPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ProtectionPrefs(prefs);
  }

  bool get protectionEnabled => _prefs.getBool(_keyProtectionEnabled) ?? false;

  Future<void> setProtectionEnabled(bool value) async {
    await _prefs.setBool(_keyProtectionEnabled, value);
  }
}
