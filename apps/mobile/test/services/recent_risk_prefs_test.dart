import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_mobile/services/recent_risk_prefs.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('default window is m30 with no stored event', () async {
    final prefs = await RecentRiskPrefs.load();
    expect(prefs.window, RecentRiskWindow.m30);
    expect(prefs.event, isNull);
  });

  test('setEvent and clearEvent roundtrip', () async {
    final prefs = await RecentRiskPrefs.load();
    final event = RecentRiskEvent(
      noticedAt: DateTime(2025, 6, 8, 12),
      riskLevel: RiskLevel.medium,
      reasons: const [RecentRiskReason.strongSignal],
    );
    await prefs.setEvent(event);
    expect(prefs.event?.riskLevel, RiskLevel.medium);
    await prefs.clearEvent();
    expect(prefs.event, isNull);
  });

  test('acknowledge persists acknowledged flag', () async {
    final prefs = await RecentRiskPrefs.load();
    await prefs.setEvent(
      RecentRiskEvent(
        noticedAt: DateTime(2025, 6, 8, 12),
        riskLevel: RiskLevel.high,
      ),
    );
    await prefs.acknowledge();
    expect(prefs.event?.acknowledged, isTrue);
  });

  test('load picks up storage written outside RecentRiskPrefs', () async {
    final raw = await SharedPreferences.getInstance();
    await raw.setString(
      'recent_risk_window',
      RecentRiskWindow.off.storageKey,
    );

    final prefs = await RecentRiskPrefs.load();
    expect(prefs.window, RecentRiskWindow.off);
  });

  test('setWindowOffAndClear atomically clears event', () async {
    final prefs = await RecentRiskPrefs.load();
    await prefs.setEvent(
      RecentRiskEvent(
        noticedAt: DateTime(2025, 6, 8, 12),
        riskLevel: RiskLevel.medium,
      ),
    );
    await prefs.setWindowOffAndClear();
    expect(prefs.window, RecentRiskWindow.off);
    expect(prefs.event, isNull);
  });
}
