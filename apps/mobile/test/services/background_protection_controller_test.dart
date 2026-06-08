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

  ({
    BackgroundProtectionController controller,
    List<ScanState> mirrored,
    List<bool> runningFlags,
  }) buildController({
    required FakeForegroundServiceController fgs,
    BackgroundProtectionPreflightResult preflight =
        const BackgroundProtectionPreflightResult.ok(),
  }) {
    final mirrored = <ScanState>[];
    final runningFlags = <bool>[];

    final controller = BackgroundProtectionController(
      foregroundService: fgs,
      preflight: _FakePreflight(preflight),
      isAndroidPlatform: true,
      applyMirroredScanState: mirrored.add,
      pauseMainProtection: () async {},
      onServiceRunningChanged: runningFlags.add,
    );

    return (
      controller: controller,
      mirrored: mirrored,
      runningFlags: runningFlags
    );
  }

  test('enable persists pref and starts service after preflight', () async {
    final fgs = FakeForegroundServiceController();
    final built = buildController(fgs: fgs);

    final ok = await built.controller.enable();
    expect(ok, isTrue);
    expect(fgs.running, isTrue);

    final prefs = await BackgroundProtectionPrefs.load();
    expect(prefs.backgroundProtectionEnabled, isTrue);
    expect(prefs.explicitlyStopped, isFalse);
    expect(built.controller.state.serviceRunning, isTrue);
    expect(built.runningFlags, contains(true));
  });

  test('notification denied preflight does not start service', () async {
    final fgs = FakeForegroundServiceController();
    final built = buildController(
      fgs: fgs,
      preflight: const BackgroundProtectionPreflightResult.fail(
        BackgroundProtectionPreflightFailure.notificationDenied,
      ),
    );

    final ok = await built.controller.enable();
    expect(ok, isFalse);
    expect(fgs.running, isFalse);

    final prefs = await BackgroundProtectionPrefs.load();
    expect(prefs.backgroundProtectionEnabled, isFalse);
    expect(built.controller.state.lastFailureMessage, isNotNull);
  });

  test('disable records explicit stop and stops service', () async {
    final fgs = FakeForegroundServiceController()..running = true;
    final built = buildController(fgs: fgs);
    await built.controller.enable();

    await built.controller.disable();

    expect(fgs.running, isFalse);
    final prefs = await BackgroundProtectionPrefs.load();
    expect(prefs.backgroundProtectionEnabled, isFalse);
    expect(prefs.explicitlyStopped, isTrue);
    expect(built.controller.state.enabled, isFalse);
    expect(built.runningFlags.last, isFalse);
  });

  test('reconcile reports stoppedByAndroid when intent on but service off',
      () async {
    final prefs = await BackgroundProtectionPrefs.load();
    await prefs.setBackgroundProtectionEnabled(true);

    final fgs = FakeForegroundServiceController()..running = false;
    final built = buildController(fgs: fgs);

    await built.controller.reconcileBackgroundProtection();

    expect(
      built.controller.state.stoppedReason,
      BackgroundProtectionStoppedReason.stoppedByAndroid,
    );
    expect(built.controller.state.showsStoppedByAndroidBanner, isTrue);
    expect(built.runningFlags.last, isFalse);
  });

  test('reconcile clears explicit stop as plain off', () async {
    final prefs = await BackgroundProtectionPrefs.load();
    await prefs.recordExplicitStop();

    final fgs = FakeForegroundServiceController()..running = false;
    final built = buildController(fgs: fgs);

    await built.controller.reconcileBackgroundProtection();

    expect(built.controller.state.enabled, isFalse);
    expect(
      built.controller.state.stoppedReason,
      BackgroundProtectionStoppedReason.none,
    );

    final reloaded = await BackgroundProtectionPrefs.load();
    expect(reloaded.explicitlyStopped, isFalse);
  });

  test('task snapshot mirrors scan state to main isolate', () async {
    final fgs = FakeForegroundServiceController();
    final built = buildController(fgs: fgs);

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

    expect(built.controller.state.serviceRunning, isTrue);
    expect(built.mirrored, hasLength(1));
    expect(built.mirrored.single.status, ScanStatus.scanning);
    expect(built.mirrored.single.otherNearbySignals, isEmpty);
    expect(built.runningFlags.last, isTrue);
  });

  test('stopped snapshot sets stoppedByAndroid when service was killed',
      () async {
    final fgs = FakeForegroundServiceController();
    final built = buildController(fgs: fgs);

    fgs.emitTaskData(
      const BackgroundProtectionSnapshot(
        status: ScanStatus.paused,
        riskLevel: RiskLevel.low,
        score: 0,
        reasonLabels: [],
        possibleRiskCount: 0,
        otherNearbyCount: 0,
        isDemoMode: false,
        serviceRunning: false,
        stoppedReason: BackgroundProtectionStoppedReason.stoppedByAndroid,
      ).toJson(),
    );

    expect(built.controller.state.enabled, isTrue);
    expect(built.controller.state.serviceRunning, isFalse);
    expect(
      built.controller.state.stoppedReason,
      BackgroundProtectionStoppedReason.stoppedByAndroid,
    );
    expect(built.mirrored, isEmpty);
  });
}
