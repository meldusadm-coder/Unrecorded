import 'package:test/test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';

void main() {
  final noticedAt = DateTime(2025, 6, 8, 12, 0);

  test('toJson contains exactly four allowed keys', () {
    final event = RecentRiskEvent(
      noticedAt: noticedAt,
      riskLevel: RiskLevel.medium,
      reasons: const [RecentRiskReason.strongSignal],
      acknowledged: false,
    );
    final json = event.toJson();
    expect(json.keys.toSet(), {
      'noticedAt',
      'riskLevel',
      'reasons',
      'acknowledged',
    });
  });

  test('fromJson roundtrip preserves fields', () {
    final original = RecentRiskEvent(
      noticedAt: noticedAt,
      riskLevel: RiskLevel.high,
      reasons: const [
        RecentRiskReason.matchedKnownPattern,
        RecentRiskReason.repeatedSighting,
      ],
      acknowledged: false,
    );
    final restored = RecentRiskEvent.fromJson(original.toJson());
    expect(restored, isNotNull);
    expect(restored!.noticedAt, original.noticedAt);
    expect(restored.riskLevel, original.riskLevel);
    expect(restored.reasons, original.reasons);
    expect(restored.acknowledged, false);
  });

  test('fromJson ignores unexpected keys and drops unknown reason names', () {
    final json = {
      'noticedAt': noticedAt.toIso8601String(),
      'riskLevel': 'medium',
      'reasons': ['strongSignal', 'unknownReason', 'connectable'],
      'acknowledged': false,
      'deviceName': 'Ray-Ban Meta',
      'mac': 'aa:bb:cc:dd:ee:ff',
    };
    final restored = RecentRiskEvent.fromJson(json);
    expect(restored, isNotNull);
    expect(restored!.reasons, [
      RecentRiskReason.strongSignal,
      RecentRiskReason.connectable,
    ]);
  });

  test('isActiveReminder respects window and acknowledged', () {
    final event = RecentRiskEvent(
      noticedAt: noticedAt,
      riskLevel: RiskLevel.medium,
    );
    expect(
      event.isActiveReminder(
        RecentRiskWindow.m30,
        noticedAt.add(const Duration(minutes: 29)),
      ),
      isTrue,
    );
    expect(
      event.isActiveReminder(
        RecentRiskWindow.m30,
        noticedAt.add(const Duration(minutes: 31)),
      ),
      isFalse,
    );
    expect(
      event.isActiveReminder(RecentRiskWindow.off, noticedAt),
      isFalse,
    );
    expect(
      event.copyWith(acknowledged: true).isActiveReminder(
            RecentRiskWindow.m30,
            noticedAt.add(const Duration(minutes: 1)),
          ),
      isFalse,
    );
  });

  test('isRecentRiskReminderVisible suppresses live alert', () {
    final event = RecentRiskEvent(
      noticedAt: noticedAt,
      riskLevel: RiskLevel.medium,
    );
    expect(
      isRecentRiskReminderVisible(
        event: event,
        window: RecentRiskWindow.m30,
        hasLiveAlert: true,
        now: noticedAt.add(const Duration(minutes: 5)),
      ),
      isFalse,
    );
    expect(
      isRecentRiskReminderVisible(
        event: event,
        window: RecentRiskWindow.m30,
        hasLiveAlert: false,
        now: noticedAt.add(const Duration(minutes: 5)),
      ),
      isTrue,
    );
  });
}
