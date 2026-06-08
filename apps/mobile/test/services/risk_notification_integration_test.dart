import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_mobile/features/scan/scan_state.dart';
import 'package:unrecorded_mobile/router.dart';
import 'package:unrecorded_mobile/services/protection_status_notification.dart';
import 'package:unrecorded_mobile/services/risk_notification_service.dart';
import 'package:unrecorded_mobile/services/scan_lifecycle_coordinator.dart';
import 'package:unrecorded_mobile/services/scan_runtime.dart';
import 'package:unrecorded_mobile/services/scanner_provider.dart';
import 'package:unrecorded_mobile/services/signal_ui_mapper.dart';
import 'package:unrecorded_radio/unrecorded_radio.dart';

class _RecordingNotificationService extends RiskNotificationService {
  _RecordingNotificationService() : super(RiskNotificationService.sharedPlugin);

  ScanState? lastSyncedState;
  RiskLevel? lastRiskAlertLevel;
  var riskAlertCancelled = false;

  @override
  Future<void> syncProtectionStatusNotification(ScanState state) async {
    lastSyncedState = state;
    await super.syncProtectionStatusNotification(state);
  }

  @override
  Future<void> showRiskAlertIfEnabled({required RiskLevel riskLevel}) async {
    lastRiskAlertLevel = riskLevel;
    await super.showRiskAlertIfEnabled(riskLevel: riskLevel);
  }

  @override
  Future<void> cancelRiskAlert() async {
    riskAlertCancelled = true;
    await super.cancelRiskAlert();
  }

  @override
  Future<bool> notificationsOsEnabled() async => true;
}

class _TestRuntime extends ScanRuntime {
  _TestRuntime(this._result);

  final ScanPreflightResult _result;

  @override
  bool get isAndroid => true;

  @override
  Future<ScanPreflightResult> ensureAndroidReady() async => _result;
}

ScanController _controllerWithNotifications(
  _RecordingNotificationService notifications, {
  required RadioScanner scanner,
  ScanRuntime? runtime,
  ScannerMode scannerMode = ScannerMode.demo,
}) {
  final pipeline = DetectionPipeline();
  final coordinator = ScanLifecycleCoordinator(
    scannerFactory: () => scanner,
    runtime: runtime ?? _TestRuntime(const ScanPreflightResult.ok()),
    scannerModeFactory: () => scannerMode,
    pipeline: pipeline,
    startupGraceDuration: Duration.zero,
    requiredElevatedScans: 1,
  );
  return ScanController(
    coordinator: coordinator,
    pipeline: pipeline,
    mapper: const SignalUiMapper(),
    onStateChanged: (previous, state) {
      unawaited(notifications.syncProtectionStatusNotification(state));

      if (previous.status != ScanStatus.possibleRiskDetected &&
          state.status == ScanStatus.possibleRiskDetected) {
        unawaited(
          notifications.showRiskAlertIfEnabled(riskLevel: state.riskLevel),
        );
      }

      final riskCleared = previous.hasElevatedRisk && !state.hasElevatedRisk;
      final leftAlert = previous.status == ScanStatus.possibleRiskDetected &&
          state.status != ScanStatus.possibleRiskDetected;
      final blockedOrPaused = state.isBlocked ||
          state.status == ScanStatus.paused ||
          !state.protectionRequested;

      if (riskCleared || leftAlert || blockedOrPaused) {
        unawaited(notifications.cancelRiskAlert());
      }
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'risk_notifications_enabled': true,
      'notification_risk_threshold': 'mediumAndHigh',
    });
  });

  test('starting protection syncs protection status notification', () async {
    final notifications = _RecordingNotificationService();
    final controller = _controllerWithNotifications(
      notifications,
      scanner: FakeRadioScanner(),
    );

    await controller.startProtection(persist: false);

    expect(notifications.lastSyncedState?.protectionRequested, isTrue);
    expect(
      shouldShowProtectionStatusNotification(notifications.lastSyncedState!),
      isTrue,
    );

    await controller.pauseProtection(persist: false);
    expect(notifications.riskAlertCancelled, isTrue);
  });

  test('possibleRiskDetected triggers separate risk alert path', () async {
    final notifications = _RecordingNotificationService();
    final controller = _controllerWithNotifications(
      notifications,
      scanner: FakeRadioScanner(),
    );

    await controller.startProtection(persist: false);
    controller.simulateHighRiskAlert();

    expect(controller.state.status, ScanStatus.possibleRiskDetected);
    expect(notifications.lastRiskAlertLevel, isNotNull);
    expect(
      shouldShowProtectionStatusNotification(controller.state),
      isTrue,
    );
  });

  test('notification tap payloads are distinct', () {
    expect(notificationAlertPayload, 'alert-details');
    expect(notificationProtectionStatusPayload, 'protection-status');
    expect(
      notificationProtectionStatusPayload,
      isNot(notificationAlertPayload),
    );
    expect(alertDetailsRoute, '/alert-details');
  });

  test('blocked state should not show protection status', () async {
    final notifications = _RecordingNotificationService();
    final controller = _controllerWithNotifications(
      notifications,
      scanner: FakeRadioScanner(),
      runtime: _TestRuntime(
        const ScanPreflightResult.fail(ScanPreflightFailure.permissionDenied),
      ),
      scannerMode: ScannerMode.auto,
    );

    await controller.startProtection(persist: false);
    expect(controller.state.isBlocked, isTrue);
    expect(
      shouldShowProtectionStatusNotification(controller.state),
      isFalse,
    );
  });
}
