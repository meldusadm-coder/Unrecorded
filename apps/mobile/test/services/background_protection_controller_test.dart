import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_mobile/features/scan/scan_state.dart';
import 'package:unrecorded_mobile/services/background_protection_controller.dart';
import 'package:unrecorded_mobile/services/background_protection_preflight.dart';
import 'package:unrecorded_mobile/services/background_protection_prefs.dart';
import 'package:unrecorded_mobile/services/background_protection_snapshot.dart';
import 'package:unrecorded_mobile/services/risk_notification_service.dart';
import 'package:unrecorded_mobile/services/scan_runtime.dart';

import '../support/fake_foreground_service_controller.dart';

class _FakePreflight extends BackgroundProtectionPreflight {
  _FakePreflight(this._result)
      : super(
          runtime: const ScanRuntime(),
          notifications: RiskNotificationService(
            RiskNotificationService.sharedPlugin,
          ),
        );

  final BackgroundProtectionPreflightResult _result;

  @override
  Future<BackgroundProtectionPreflightResult> check({
    bool requestPermissions = true,
  }) async {
    return _result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  BackgroundProtectionController buildController({
    required FakeForegroundServiceController fgs,
    BackgroundProtectionPreflightResult preflight =
        const BackgroundProtectionPreflightResult.ok(),
    ScanState? mirrored,
    List<ScanState> mirroredStates = const [],
    List<bool> serviceRunningFlags = const [],
  }) {
    final captured = <ScanState>[...mirroredStates];
    final runningFlags = <bool>[...serviceRunningFlags];

    return BackgroundProtectionController(
      foregroundService: fgs,
      preflight: _FakePreflight(preflight),
      isAndroidPlatform: true,
      applyMirroredScanState: (state) {
        captured.add(state);
      },
      pauseMainProtection: () async {},
      onServiceRunningChanged: (running) => runningFlags.add(running),
      notifications: RiskNotificationService(
        RiskNotificationService.sharedPlugin,
      ),
    );
  }

  test('enable persists pref and starts service after preflight', () async {
    final fgs = FakeForegroundServiceController();
    final controller = buildController(fgs: fgs);

    final ok = await controller.enable();
    expect(ok, isTrue);
    expect(fgs.running, isTrue);

    final prefs = await BackgroundProtectionPrefs.load();
    expect(prefs.backgroundProtectionEnabled, isTrue);
    expect(prefs.explicitlyStopped, isFalse);
    expect(controller.state.serviceRunning, isTrue);
  });

  test('notification denied preflight does not start service', () async {
    final fgs = FakeForegroundServiceController();
    final controller = buildController(
      fgs: fgs,
      preflight: const BackgroundProtectionPreflightResult.fail(
        BackgroundProtectionPreflightFailure.notificationDenied,
      ),
    );

    final ok = await controller.enable();
    expect(ok, isFalse);
    expect(fgs.running, isFalse);

    final prefs = await BackgroundProtectionPrefs.load();
    expect(prefs.backgroundProtectionEnabled, isFalse);
    expect(controller.state.lastFailureMessage, isNotNull);
  });

  test('disable records explicit stop and stops service', () async {
    final fgs = FakeForegroundServiceController()..running = true;
    final controller = buildController(fgs: fgs);
    await controller.enable();

    await controller.disable();

    expect(fgs.running, isFalse);
    final prefs = await BackgroundProtectionPrefs.load();
    expect(prefs.backgroundProtectionEnabled, isFalse);
    expect(prefs.explicitlyStopped, isTrue);
    expect(controller.state.enabled, isFalse);
  });

  test('reconcile reports stoppedByAndroid when intent on but service off',
      () async {
    final prefs = await BackgroundProtectionPrefs.load();
    await prefs.setBackgroundProtectionEnabled(true);

    final fgs = FakeForegroundServiceController()..running = false;
    final controller = buildController(fgs: fgs);

    await controller.reconcileOnResume();

    expect(
      controller.state.stoppedReason,
      BackgroundProtectionStoppedReason.stoppedByAndroid,
    );
    expect(controller.state.showsStoppedByAndroidBanner, isTrue);
  });

  test('reconcile clears explicit stop as plain off', () async {
    final prefs = await BackgroundProtectionPrefs.load();
    await prefs.recordExplicitStop();

    final fgs = FakeForegroundServiceController()..running = false;
    final controller = buildController(fgs: fgs);

    await controller.reconcileOnResume();

    expect(controller.state.enabled, isFalse);
    expect(
      controller.state.stoppedReason,
      BackgroundProtectionStoppedReason.none,
    );

    final reloaded = await BackgroundProtectionPrefs.load();
    expect(reloaded.explicitlyStopped, isFalse);
  });

  test('task snapshot updates mirrored state', () async {
    final fgs = FakeForegroundServiceController();
    final controller = buildController(fgs: fgs);

    fgs.emitTaskData(
      const BackgroundProtectionSnapshot(
        status: ScanStatus.scanning,
        riskLevel: RiskLevel.low,
        score: 0,
        reasonLabels: [],
        possibleRiskCount: 0,
        otherNearbyCount: 3,
        isDemoMode: false,
        serviceRunning: true,
      ).toJson(),
    );

    expect(controller.state.serviceRunning, isTrue);
  });
}
