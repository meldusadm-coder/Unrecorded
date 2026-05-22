import 'package:shared_preferences/shared_preferences.dart';
import 'package:unrecorded_radio/unrecorded_radio.dart';

import 'scan_runtime.dart';

const _keyScannerMode = 'dev_scanner_mode';
const _keyDemoScenario = 'dev_demo_scenario';

/// Debug-only persisted scanner overrides (ignored in release).
class DevTestingPrefs {
  DevTestingPrefs(this._prefs);

  final SharedPreferences _prefs;

  static Future<DevTestingPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    return DevTestingPrefs(prefs);
  }

  ScannerMode? get scannerMode {
    final raw = _prefs.getString(_keyScannerMode);
    if (raw == null) return null;
    return raw == 'demo' ? ScannerMode.demo : ScannerMode.auto;
  }

  FakeDemoScenario? get demoScenario {
    final raw = _prefs.getString(_keyDemoScenario);
    if (raw == null) return null;
    return fakeDemoScenarioFromEnvironment(raw);
  }

  Future<void> setScannerMode(ScannerMode? mode) async {
    if (mode == null) {
      await _prefs.remove(_keyScannerMode);
      return;
    }
    await _prefs.setString(
      _keyScannerMode,
      mode == ScannerMode.demo ? 'demo' : 'auto',
    );
  }

  Future<void> setDemoScenario(FakeDemoScenario scenario) async {
    await _prefs.setString(_keyDemoScenario, scenario.name);
  }

  Future<void> clearAll() async {
    await _prefs.remove(_keyScannerMode);
    await _prefs.remove(_keyDemoScenario);
  }
}
