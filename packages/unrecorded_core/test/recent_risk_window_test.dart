import 'package:test/test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';

void main() {
  test('defaultWindow is m30', () {
    expect(RecentRiskWindowX.defaultWindow, RecentRiskWindow.m30);
  });

  test('off has null duration', () {
    expect(RecentRiskWindow.off.duration, isNull);
  });

  test('durations match expected values', () {
    expect(RecentRiskWindow.m15.duration, const Duration(minutes: 15));
    expect(RecentRiskWindow.m30.duration, const Duration(minutes: 30));
    expect(RecentRiskWindow.h1.duration, const Duration(hours: 1));
    expect(RecentRiskWindow.h3.duration, const Duration(hours: 3));
  });

  test('fromStorage falls back to default on unknown or null', () {
    expect(RecentRiskWindowX.fromStorage(null), RecentRiskWindow.m30);
    expect(RecentRiskWindowX.fromStorage(''), RecentRiskWindow.m30);
    expect(RecentRiskWindowX.fromStorage('bogus'), RecentRiskWindow.m30);
    expect(RecentRiskWindowX.fromStorage('h1'), RecentRiskWindow.h1);
    expect(RecentRiskWindowX.fromStorage('off'), RecentRiskWindow.off);
  });
}
