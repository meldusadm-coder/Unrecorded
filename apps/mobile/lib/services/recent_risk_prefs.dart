import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:unrecorded_core/unrecorded_core.dart';

const _keyRecentRiskWindow = 'recent_risk_window';
const _keyRecentRiskEvent = 'recent_risk_event';

/// Persists the latest recent possible-risk reminder and user window preference.
class RecentRiskPrefs {
  RecentRiskPrefs(this._prefs);

  final SharedPreferences _prefs;

  static Future<RecentRiskPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    return RecentRiskPrefs(prefs);
  }

  RecentRiskWindow get window =>
      RecentRiskWindowX.fromStorage(_prefs.getString(_keyRecentRiskWindow));

  Future<void> setWindow(RecentRiskWindow value) async {
    await _prefs.setString(_keyRecentRiskWindow, value.storageKey);
  }

  /// Atomically disables reminders and clears any stored event.
  Future<void> setWindowOffAndClear() async {
    await _prefs.setString(
      _keyRecentRiskWindow,
      RecentRiskWindow.off.storageKey,
    );
    await _prefs.remove(_keyRecentRiskEvent);
  }

  RecentRiskEvent? get event {
    final raw = _prefs.getString(_keyRecentRiskEvent);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return RecentRiskEvent.fromJson(
        Map<String, Object?>.from(decoded),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> setEvent(RecentRiskEvent value) async {
    await _prefs.setString(_keyRecentRiskEvent, jsonEncode(value.toJson()));
  }

  Future<void> clearEvent() async {
    await _prefs.remove(_keyRecentRiskEvent);
  }

  Future<void> acknowledge() async {
    final current = event;
    if (current == null) return;
    await setEvent(current.copyWith(acknowledged: true));
  }
}
