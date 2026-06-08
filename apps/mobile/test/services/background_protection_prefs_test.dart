import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unrecorded_mobile/services/background_protection_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('background protection defaults to off', () async {
    final prefs = await BackgroundProtectionPrefs.load();
    expect(prefs.backgroundProtectionEnabled, isFalse);
    expect(prefs.explicitlyStopped, isFalse);
  });

  test('enable and disable persist', () async {
    final prefs = await BackgroundProtectionPrefs.load();
    await prefs.setBackgroundProtectionEnabled(true);
    final reloaded = await BackgroundProtectionPrefs.load();
    expect(reloaded.backgroundProtectionEnabled, isTrue);

    await reloaded.setBackgroundProtectionEnabled(false);
    final cleared = await BackgroundProtectionPrefs.load();
    expect(cleared.backgroundProtectionEnabled, isFalse);
  });

  test('recordExplicitStop clears intent and sets marker', () async {
    final prefs = await BackgroundProtectionPrefs.load();
    await prefs.setBackgroundProtectionEnabled(true);
    await prefs.recordExplicitStop();

    final reloaded = await BackgroundProtectionPrefs.load();
    expect(reloaded.backgroundProtectionEnabled, isFalse);
    expect(reloaded.explicitlyStopped, isTrue);
  });
}
