import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_mobile/services/recent_risk_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('event becomes invisible when expiry timer fires', () {
    fakeAsync((async) {
      var now = DateTime(2025, 6, 8, 12, 0);
      final controller = RecentRiskController(now: () => now);
      async.flushMicrotasks();

      controller.setWindow(RecentRiskWindow.m15);
      async.flushMicrotasks();

      controller.recordPossibleRisk(
        riskLevel: RiskLevel.medium,
        reasons: const [],
      );
      async.flushMicrotasks();

      expect(
        controller.state.event?.isActiveReminder(
          RecentRiskWindow.m15,
          now,
        ),
        isTrue,
      );

      now = now.add(const Duration(minutes: 15));
      async.elapse(const Duration(minutes: 15));
      async.flushMicrotasks();

      expect(
        controller.state.event?.isActiveReminder(
          RecentRiskWindow.m15,
          now,
        ),
        isFalse,
      );
      controller.dispose();
    });
  });

  test('window change reschedules expiry', () {
    fakeAsync((async) {
      var now = DateTime(2025, 6, 8, 12, 0);
      final controller = RecentRiskController(now: () => now);
      async.flushMicrotasks();

      controller.recordPossibleRisk(
        riskLevel: RiskLevel.medium,
        reasons: const [],
      );
      async.flushMicrotasks();

      controller.setWindow(RecentRiskWindow.h1);
      async.flushMicrotasks();

      now = now.add(const Duration(minutes: 20));
      async.elapse(const Duration(minutes: 20));
      async.flushMicrotasks();
      expect(
        controller.state.event?.isActiveReminder(RecentRiskWindow.h1, now),
        isTrue,
      );

      now = now.add(const Duration(minutes: 41));
      async.elapse(const Duration(minutes: 41));
      async.flushMicrotasks();
      expect(
        controller.state.event?.isActiveReminder(RecentRiskWindow.h1, now),
        isFalse,
      );
      controller.dispose();
    });
  });
}
