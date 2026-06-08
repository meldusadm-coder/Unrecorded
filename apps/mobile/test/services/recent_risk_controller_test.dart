import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_mobile/services/recent_risk_controller.dart';
import 'package:unrecorded_mobile/services/recent_risk_prefs.dart';

void main() {
  final fixedNow = DateTime(2025, 6, 8, 12, 0);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('starts with default state before async load completes', () {
    final completer = Completer<void>();
    final controller = RecentRiskController(
      now: () => fixedNow,
      prefsFactory: () async {
        await completer.future;
        return RecentRiskPrefs.load();
      },
    );

    expect(controller.state.event, isNull);
    expect(controller.state.window, RecentRiskWindow.m30);
    controller.dispose();
    completer.complete();
  });

  test('load surfaces persisted event and window', () async {
    final noticedAt = fixedNow.subtract(const Duration(minutes: 5));
    SharedPreferences.setMockInitialValues({
      'recent_risk_window': 'h1',
      'recent_risk_event':
          '{"noticedAt":"${noticedAt.toIso8601String()}","riskLevel":"medium","reasons":["strongSignal"],"acknowledged":false}',
    });

    final controller = RecentRiskController(now: () => fixedNow);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.window, RecentRiskWindow.h1);
    expect(controller.state.event?.riskLevel, RiskLevel.medium);
    controller.dispose();
  });

  test('setWindow off emits single clean state', () async {
    final controller = RecentRiskController(now: () => fixedNow);
    await Future<void>.delayed(Duration.zero);

    await controller.recordPossibleRisk(
      riskLevel: RiskLevel.medium,
      reasons: const [RecentRiskReason.strongSignal],
    );
    await controller.setWindow(RecentRiskWindow.off);

    expect(controller.state.window, RecentRiskWindow.off);
    expect(controller.state.event, isNull);

    final prefs = await RecentRiskPrefs.load();
    expect(prefs.window, RecentRiskWindow.off);
    expect(prefs.event, isNull);
    controller.dispose();
  });

  test('generation token prevents stale load from clobbering setWindow off',
      () async {
    final loadGate = Completer<void>();
    SharedPreferences.setMockInitialValues({
      'recent_risk_window': 'h3',
      'recent_risk_event':
          '{"noticedAt":"${fixedNow.toIso8601String()}","riskLevel":"high","reasons":[],"acknowledged":false}',
    });

    var loadCount = 0;
    final controller = RecentRiskController(
      now: () => fixedNow,
      prefsFactory: () async {
        loadCount++;
        if (loadCount == 1) {
          await loadGate.future;
        }
        return RecentRiskPrefs.load();
      },
    );

    await controller.setWindow(RecentRiskWindow.off);
    expect(controller.state.window, RecentRiskWindow.off);
    expect(controller.state.event, isNull);

    loadGate.complete();
    await pumpEventQueue(times: 3);

    expect(controller.state.window, RecentRiskWindow.off);
    expect(controller.state.event, isNull);
    controller.dispose();
  });

  test('does not update state after dispose', () async {
    final loadGate = Completer<void>();
    var loadCount = 0;
    final controller = RecentRiskController(
      now: () => fixedNow,
      prefsFactory: () async {
        loadCount++;
        if (loadCount == 1) {
          await loadGate.future;
        }
        return RecentRiskPrefs.load();
      },
    );

    final stateBeforeDispose = controller.state;
    controller.dispose();
    loadGate.complete();
    await pumpEventQueue(times: 3);
    expect(stateBeforeDispose.window, RecentRiskWindow.m30);
  });
}
