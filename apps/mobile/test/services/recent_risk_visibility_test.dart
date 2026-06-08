import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_mobile/services/recent_risk_controller.dart';

void main() {
  final fixedNow = DateTime(2025, 6, 8, 12, 0);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('visible within window when not acknowledged', () async {
    final controller = RecentRiskController(now: () => fixedNow);
    await Future<void>.delayed(Duration.zero);

    await controller.recordPossibleRisk(
      riskLevel: RiskLevel.medium,
      reasons: const [RecentRiskReason.strongSignal],
    );

    expect(
      isRecentRiskReminderVisible(
        event: controller.state.event,
        window: controller.state.window,
        hasLiveAlert: false,
        now: fixedNow.add(const Duration(minutes: 10)),
      ),
      isTrue,
    );
    controller.dispose();
  });

  test('hidden after expiry and when acknowledged', () async {
    final controller = RecentRiskController(now: () => fixedNow);
    await Future<void>.delayed(Duration.zero);

    await controller.recordPossibleRisk(
      riskLevel: RiskLevel.medium,
      reasons: const [],
    );

    expect(
      isRecentRiskReminderVisible(
        event: controller.state.event,
        window: RecentRiskWindow.m30,
        hasLiveAlert: false,
        now: fixedNow.add(const Duration(minutes: 31)),
      ),
      isFalse,
    );

    await controller.recordPossibleRisk(
      riskLevel: RiskLevel.medium,
      reasons: const [],
    );
    await controller.acknowledge();
    expect(
      isRecentRiskReminderVisible(
        event: controller.state.event,
        window: RecentRiskWindow.m30,
        hasLiveAlert: false,
        now: fixedNow.add(const Duration(minutes: 1)),
      ),
      isFalse,
    );
    controller.dispose();
  });

  test('live alert suppresses recent reminder', () {
    final event = RecentRiskEvent(
      noticedAt: fixedNow,
      riskLevel: RiskLevel.medium,
    );
    expect(
      isRecentRiskReminderVisible(
        event: event,
        window: RecentRiskWindow.m30,
        hasLiveAlert: true,
        now: fixedNow.add(const Duration(minutes: 1)),
      ),
      isFalse,
    );
  });

  test('off window suppresses visibility', () {
    final event = RecentRiskEvent(
      noticedAt: fixedNow,
      riskLevel: RiskLevel.medium,
    );
    expect(
      isRecentRiskReminderVisible(
        event: event,
        window: RecentRiskWindow.off,
        hasLiveAlert: false,
        now: fixedNow,
      ),
      isFalse,
    );
  });
}
