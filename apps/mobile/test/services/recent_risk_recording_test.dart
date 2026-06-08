import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_mobile/features/scan/scan_state.dart';
import 'package:unrecorded_mobile/services/recent_risk_controller.dart';
import 'package:unrecorded_mobile/services/recent_risk_prefs.dart';
import 'package:unrecorded_mobile/services/risk_notification_service.dart';
import 'package:unrecorded_mobile/services/scan_lifecycle_coordinator.dart';
import 'package:unrecorded_mobile/services/scan_runtime.dart';
import 'package:unrecorded_mobile/services/scanner_provider.dart';
import 'package:unrecorded_mobile/services/signal_ui_mapper.dart';
import 'package:unrecorded_radio/unrecorded_radio.dart';

class _DenyNotificationsService extends RiskNotificationService {
  _DenyNotificationsService() : super(RiskNotificationService.sharedPlugin);

  @override
  Future<bool> notificationsOsEnabled() async => false;

  @override
  Future<void> showRiskAlertIfEnabled({required RiskLevel riskLevel}) async {
    // Simulates a failed notification display without crashing the scan loop.
    return;
  }
}

class _TestRuntime extends ScanRuntime {
  @override
  bool get isAndroid => true;

  @override
  Future<ScanPreflightResult> ensureAndroidReady() async =>
      const ScanPreflightResult.ok();
}

ScanController _controllerWithRecentRiskRecording({
  required RadioScanner scanner,
  required RecentRiskController recentRisk,
  RiskNotificationService? notifications,
}) {
  final pipeline = DetectionPipeline();
  final coordinator = ScanLifecycleCoordinator(
    scannerFactory: () => scanner,
    runtime: _TestRuntime(),
    scannerModeFactory: () => ScannerMode.demo,
    pipeline: pipeline,
    startupGraceDuration: Duration.zero,
    requiredElevatedScans: 1,
  );
  final notificationService = notifications ?? _DenyNotificationsService();

  return ScanController(
    coordinator: coordinator,
    pipeline: pipeline,
    mapper: const SignalUiMapper(),
    onStateChanged: (previous, state) {
      if (previous.status != ScanStatus.possibleRiskDetected &&
          state.status == ScanStatus.possibleRiskDetected) {
        unawaited(
          recentRisk.recordPossibleRisk(
            riskLevel: state.riskLevel,
            reasons: state.safeReasonKeys,
          ),
        );
        unawaited(
          notificationService.showRiskAlertIfEnabled(
            riskLevel: state.riskLevel,
          ),
        );
      }
    },
  );
}

void main() {
  final fixedNow = DateTime(2025, 6, 8, 12, 0);

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'risk_notifications_enabled': true,
      'notification_risk_threshold': 'mediumAndHigh',
    });
  });

  test('entering possibleRiskDetected records recent-risk event', () async {
    final recentRisk = RecentRiskController(now: () => fixedNow);
    await Future<void>.delayed(Duration.zero);

    final controller = _controllerWithRecentRiskRecording(
      scanner: FakeRadioScanner(),
      recentRisk: recentRisk,
    );

    await controller.startProtection(persist: false);
    controller.simulateHighRiskAlert();
    await Future<void>.delayed(Duration.zero);

    expect(recentRisk.state.event, isNotNull);
    expect(recentRisk.state.event!.riskLevel, isNot(RiskLevel.low));
    recentRisk.dispose();
  });

  test('records even when notification permission denied or display fails',
      () async {
    final recentRisk = RecentRiskController(now: () => fixedNow);
    await Future<void>.delayed(Duration.zero);

    final controller = _controllerWithRecentRiskRecording(
      scanner: FakeRadioScanner(),
      recentRisk: recentRisk,
      notifications: _DenyNotificationsService(),
    );

    await controller.startProtection(persist: false);
    controller.simulateHighRiskAlert();
    await Future<void>.delayed(Duration.zero);

    expect(recentRisk.state.event, isNotNull);
    recentRisk.dispose();
  });

  test('records event with empty reasons and privacy-safe JSON only', () async {
    final recentRisk = RecentRiskController(now: () => fixedNow);
    await Future<void>.delayed(Duration.zero);

    await recentRisk.recordPossibleRisk(
      riskLevel: RiskLevel.medium,
      reasons: const [],
    );

    final prefs = await RecentRiskPrefs.load();
    final raw = prefs.event;
    expect(raw, isNotNull);
    expect(raw!.reasons, isEmpty);

    final stored = jsonDecode(
      (await SharedPreferences.getInstance()).getString('recent_risk_event')!,
    ) as Map<String, dynamic>;
    expect(stored.keys.toSet(), {
      'noticedAt',
      'riskLevel',
      'reasons',
      'acknowledged',
    });
    expect(stored['reasons'], isEmpty);
    recentRisk.dispose();
  });

  test('safeReasonKeys populated on possibleRiskDetected', () async {
    final controller = _controllerWithRecentRiskRecording(
      scanner: FakeRadioScanner(),
      recentRisk: RecentRiskController(now: () => fixedNow),
    );

    await controller.startProtection(persist: false);
    controller.simulateHighRiskAlert();

    expect(controller.state.status, ScanStatus.possibleRiskDetected);
    expect(controller.state.safeReasonKeys, isNotEmpty);
    for (final reason in controller.state.safeReasonKeys) {
      expect(RecentRiskReason.values, contains(reason));
    }
  });
}
