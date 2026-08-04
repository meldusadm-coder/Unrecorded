import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_mobile/features/scan/scan_state.dart';
import 'package:unrecorded_mobile/services/scan_lifecycle_coordinator.dart';
import 'package:unrecorded_mobile/services/scan_runtime.dart';
import 'package:unrecorded_mobile/services/scanner_cadence_config.dart';
import 'package:unrecorded_mobile/services/protection_state.dart';
import 'package:unrecorded_mobile/services/scanner_provider.dart';
import 'package:unrecorded_mobile/services/signal_ui_mapper.dart';
import 'package:unrecorded_radio/unrecorded_radio.dart';

class _TestRuntime extends ScanRuntime {
  _TestRuntime(this.result, {bool isAndroid = true}) : _isAndroid = isAndroid;

  final ScanPreflightResult result;
  final bool _isAndroid;

  @override
  bool get isAndroid => _isAndroid;

  @override
  Future<ScanPreflightResult> ensureAndroidReady() async => result;
}

ScanController _controller({
  required RadioScanner scanner,
  required ScanRuntime runtime,
  ScannerMode scannerMode = ScannerMode.auto,
  Duration startupGraceDuration = Duration.zero,
  int requiredElevatedScans = 1,
  ScannerCadenceConfig cadence = const ScannerCadenceConfig(
    scanWindow: Duration(seconds: 30),
    restInterval: Duration(seconds: 30),
  ),
}) {
  final pipeline = DetectionPipeline();
  final coordinator = ScanLifecycleCoordinator(
    scannerFactory: () => scanner,
    runtime: runtime,
    scannerModeFactory: () => scannerMode,
    pipeline: pipeline,
    cadence: cadence,
    startupGraceDuration: startupGraceDuration,
    requiredElevatedScans: requiredElevatedScans,
  );
  return ScanController(
    coordinator: coordinator,
    pipeline: pipeline,
    mapper: const SignalUiMapper(),
    backgroundClaim: BackgroundOwnershipClaim(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('startProtection sets permissionDenied when preflight fails', () async {
    final controller = _controller(
      scanner: FakeRadioScanner(),
      runtime: _TestRuntime(
        const ScanPreflightResult.fail(ScanPreflightFailure.permissionDenied),
      ),
    );

    await controller.startProtection();

    expect(controller.state.status, ScanStatus.permissionDenied);
    expect(controller.state.protectionRequested, isTrue);
  });

  test('startProtection transitions to scanning when preflight succeeds',
      () async {
    final streamController =
        StreamController<List<RadioScanResult>>.broadcast();
    final scanner = _StreamScanner(streamController.stream);
    final controller = _controller(
      scanner: scanner,
      runtime: _TestRuntime(const ScanPreflightResult.ok()),
    );

    await controller.startProtection();

    expect(controller.state.status, ScanStatus.scanning);
    await streamController.close();
    await controller.pauseProtection();
  });

  test('startProtection sets bluetoothUnsupported status', () async {
    final controller = _controller(
      scanner: FakeRadioScanner(),
      runtime: _TestRuntime(
        const ScanPreflightResult.fail(
          ScanPreflightFailure.bluetoothUnsupported,
        ),
      ),
    );

    await controller.startProtection();

    expect(controller.state.status, ScanStatus.bluetoothUnsupported);
  });

  test('startProtection sets bluetoothOff status', () async {
    final controller = _controller(
      scanner: FakeRadioScanner(),
      runtime: _TestRuntime(
        const ScanPreflightResult.fail(ScanPreflightFailure.bluetoothOff),
      ),
    );

    await controller.startProtection();

    expect(controller.state.status, ScanStatus.bluetoothOff);
  });

  test('startProtection sets permissionPermanentlyDenied status', () async {
    final controller = _controller(
      scanner: FakeRadioScanner(),
      runtime: _TestRuntime(
        const ScanPreflightResult.fail(
          ScanPreflightFailure.permissionPermanentlyDenied,
        ),
      ),
    );

    await controller.startProtection();

    expect(controller.state.status, ScanStatus.permissionPermanentlyDenied);
  });

  test('scan stream error sets error state', () async {
    final streamController =
        StreamController<List<RadioScanResult>>.broadcast();
    final scanner = _StreamScanner(streamController.stream);
    final controller = _controller(
      scanner: scanner,
      runtime: _TestRuntime(const ScanPreflightResult.ok()),
    );

    await controller.startProtection();
    streamController.addError(Exception('boom'));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(controller.state.status, ScanStatus.error);
    await streamController.close();
    await controller.pauseProtection();
  });

  test('can retry startProtection after stream error', () async {
    final streamController =
        StreamController<List<RadioScanResult>>.broadcast();
    final scanner = _CountingScanner(streamController.stream);
    final controller = _controller(
      scanner: scanner,
      runtime: _TestRuntime(const ScanPreflightResult.ok()),
    );

    await controller.startProtection();
    streamController.addError(Exception('boom'));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(controller.state.status, ScanStatus.error);

    await controller.startProtection();
    expect(controller.state.status, ScanStatus.scanning);
    await streamController.close();
    await controller.pauseProtection();
  });

  test('high risk results set possibleRiskDetected', () async {
    final streamController =
        StreamController<List<RadioScanResult>>.broadcast();
    final scanner = _StreamScanner(streamController.stream);
    final controller = _controller(
      scanner: scanner,
      runtime: _TestRuntime(const ScanPreflightResult.ok()),
    );

    await controller.startProtection();

    streamController.add([
      RadioScanResult(
        id: '1',
        name: 'Ray-Ban Meta',
        rssi: -40,
        isConnectable: true,
        observedAt: DateTime.now(),
      ),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(controller.state.status, ScanStatus.possibleRiskDetected);
    expect(controller.state.lastCheckedAt, isNotNull);
    await streamController.close();
    await controller.pauseProtection();
  });

  test('scan window end does not count cached elevation toward alert',
      () async {
    final streamController =
        StreamController<List<RadioScanResult>>.broadcast();
    final scanner = _StreamScanner(streamController.stream);
    final controller = _controller(
      scanner: scanner,
      runtime: _TestRuntime(const ScanPreflightResult.ok()),
      startupGraceDuration: Duration.zero,
      requiredElevatedScans: 2,
      cadence: const ScannerCadenceConfig(
        scanWindow: Duration(milliseconds: 80),
        restInterval: Duration(seconds: 30),
      ),
    );

    await controller.startProtection();

    streamController.add([
      RadioScanResult(
        id: '1',
        name: 'Ray-Ban Meta',
        rssi: -40,
        isConnectable: true,
        observedAt: DateTime.now(),
      ),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(controller.state.status, isNot(ScanStatus.possibleRiskDetected));

    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(controller.state.status, isNot(ScanStatus.possibleRiskDetected));

    await streamController.close();
    await controller.pauseProtection();
  });

  test('two elevated batches confirm alert', () async {
    final streamController =
        StreamController<List<RadioScanResult>>.broadcast();
    final scanner = _StreamScanner(streamController.stream);
    final controller = _controller(
      scanner: scanner,
      runtime: _TestRuntime(const ScanPreflightResult.ok()),
      startupGraceDuration: Duration.zero,
      requiredElevatedScans: 2,
    );

    await controller.startProtection();

    final batch = [
      RadioScanResult(
        id: '1',
        name: 'Ray-Ban Meta',
        rssi: -40,
        isConnectable: true,
        observedAt: DateTime.now(),
      ),
    ];
    streamController.add(batch);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    streamController.add(batch);
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(controller.state.status, ScanStatus.possibleRiskDetected);
    await streamController.close();
    await controller.pauseProtection();
  });

  test('startup grace shows confirmingRisk before alert', () async {
    final streamController =
        StreamController<List<RadioScanResult>>.broadcast();
    final scanner = _StreamScanner(streamController.stream);
    final controller = _controller(
      scanner: scanner,
      runtime: _TestRuntime(const ScanPreflightResult.ok()),
      startupGraceDuration: const Duration(seconds: 5),
      requiredElevatedScans: 2,
    );

    await controller.startProtection();

    streamController.add([
      RadioScanResult(
        id: '1',
        name: 'Ray-Ban Meta',
        rssi: -40,
        isConnectable: true,
        observedAt: DateTime.now(),
      ),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(
      controller.state.status,
      anyOf(ScanStatus.scanning, ScanStatus.confirmingRisk),
    );
    expect(controller.state.riskLevel, RiskLevel.low);
    await streamController.close();
    await controller.pauseProtection();
  });

  test('simulateHighRiskAlert sets possibleRiskDetected', () {
    final controller = _controller(
      scanner: FakeRadioScanner(),
      runtime: _TestRuntime(const ScanPreflightResult.ok()),
    );

    controller.simulateHighRiskAlert();

    expect(controller.state.status, ScanStatus.possibleRiskDetected);
    expect(controller.state.riskLevel, anyOf(RiskLevel.medium, RiskLevel.high));
    expect(controller.state.alertDismissed, isFalse);
  });

  test('dismissRiskAlert hides alert until next trigger', () {
    final controller = _controller(
      scanner: FakeRadioScanner(),
      runtime: _TestRuntime(const ScanPreflightResult.ok()),
    );

    controller.simulateHighRiskAlert();
    expect(controller.state.status, ScanStatus.possibleRiskDetected);
    expect(controller.state.alertDismissed, isFalse);

    controller.dismissRiskAlert();
    expect(controller.state.status, ScanStatus.possibleRiskDetected);
    expect(controller.state.alertDismissed, isTrue);
  });

  test('dismissed alert stays dismissed across coordinator updates', () async {
    final streamController =
        StreamController<List<RadioScanResult>>.broadcast();
    final scanner = _StreamScanner(streamController.stream);
    final controller = _controller(
      scanner: scanner,
      runtime: _TestRuntime(const ScanPreflightResult.ok()),
      startupGraceDuration: Duration.zero,
      requiredElevatedScans: 1,
    );

    await controller.startProtection();

    final batch = [
      RadioScanResult(
        id: '1',
        name: 'Ray-Ban Meta',
        rssi: -40,
        isConnectable: true,
        observedAt: DateTime.now(),
      ),
    ];

    streamController.add(batch);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(controller.state.status, ScanStatus.possibleRiskDetected);
    expect(controller.state.showsRiskAlert, isTrue);

    controller.dismissRiskAlert();
    expect(controller.state.alertDismissed, isTrue);
    expect(controller.state.showsRiskAlert, isFalse);

    // A later coordinator update for the same still-elevated risk must not
    // resurrect the dismissed alert.
    streamController.add(batch);
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(controller.state.status, ScanStatus.possibleRiskDetected);
    expect(controller.state.alertDismissed, isTrue);
    expect(controller.state.showsRiskAlert, isFalse);

    await streamController.close();
    await controller.pauseProtection();
  });

  test('dismissed alert reappears when contributing risky devices change',
      () async {
    final streamController =
        StreamController<List<RadioScanResult>>.broadcast();
    final scanner = _StreamScanner(streamController.stream);
    final controller = _controller(
      scanner: scanner,
      runtime: _TestRuntime(const ScanPreflightResult.ok()),
      startupGraceDuration: Duration.zero,
      requiredElevatedScans: 1,
    );

    await controller.startProtection();

    streamController.add([
      RadioScanResult(
        id: 'glasses-a',
        name: 'Ray-Ban Meta',
        rssi: -40,
        isConnectable: true,
        observedAt: DateTime.now(),
      ),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(controller.state.showsRiskAlert, isTrue);

    controller.dismissRiskAlert();
    expect(controller.state.alertDismissed, isTrue);
    expect(controller.state.showsRiskAlert, isFalse);

    streamController.add([
      RadioScanResult(
        id: 'glasses-b',
        name: 'Meta Smart Glasses',
        rssi: -42,
        isConnectable: true,
        observedAt: DateTime.now(),
      ),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(controller.state.status, ScanStatus.possibleRiskDetected);
    expect(controller.state.alertDismissed, isFalse);
    expect(controller.state.showsRiskAlert, isTrue);

    await streamController.close();
    await controller.pauseProtection();
  });

  test('a fresh alert after risk clears resets dismissal', () async {
    final streamController =
        StreamController<List<RadioScanResult>>.broadcast();
    final scanner = _StreamScanner(streamController.stream);
    final controller = _controller(
      scanner: scanner,
      runtime: _TestRuntime(const ScanPreflightResult.ok()),
      startupGraceDuration: Duration.zero,
      requiredElevatedScans: 1,
    );

    await controller.startProtection();

    final riskBatch = [
      RadioScanResult(
        id: '1',
        name: 'Ray-Ban Meta',
        rssi: -40,
        isConnectable: true,
        observedAt: DateTime.now(),
      ),
    ];
    final benignBatch = [
      RadioScanResult(
        id: '1',
        name: 'AirPods Pro',
        rssi: -40,
        isConnectable: true,
        observedAt: DateTime.now(),
      ),
    ];

    streamController.add(riskBatch);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(controller.state.status, ScanStatus.possibleRiskDetected);

    controller.dismissRiskAlert();
    expect(controller.state.alertDismissed, isTrue);

    streamController.add(benignBatch);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(controller.state.status, isNot(ScanStatus.possibleRiskDetected));

    streamController.add(riskBatch);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(controller.state.status, ScanStatus.possibleRiskDetected);
    expect(controller.state.alertDismissed, isFalse);
    expect(controller.state.showsRiskAlert, isTrue);

    await streamController.close();
    await controller.pauseProtection();
  });

  test('non-Android auto mode is exposed as demo mode', () async {
    final controller = _controller(
      scanner: FakeRadioScanner(),
      runtime: _TestRuntime(const ScanPreflightResult.ok(), isAndroid: false),
      scannerMode: ScannerMode.auto,
    );

    await controller.startProtection();

    expect(controller.state.status, ScanStatus.scanning);
    expect(controller.state.isDemoMode, isTrue);

    await controller.pauseProtection();
  });

  test('duplicate startProtection does not create duplicate scan loops',
      () async {
    final streamController =
        StreamController<List<RadioScanResult>>.broadcast();
    final scanner = _CountingScanner(streamController.stream);
    final controller = _controller(
      scanner: scanner,
      runtime: _TestRuntime(const ScanPreflightResult.ok()),
    );

    await controller.startProtection();
    await controller.startProtection();

    expect(scanner.startCallCount, 1);
    await streamController.close();
    await controller.pauseProtection();
  });

  test('low batch after elevated batch resets confirmation', () async {
    final streamController =
        StreamController<List<RadioScanResult>>.broadcast();
    final scanner = _StreamScanner(streamController.stream);
    final controller = _controller(
      scanner: scanner,
      runtime: _TestRuntime(const ScanPreflightResult.ok()),
      startupGraceDuration: Duration.zero,
      requiredElevatedScans: 2,
    );

    await controller.startProtection();
    streamController.add([
      RadioScanResult(
        id: 'risk',
        name: 'Ray-Ban Meta',
        rssi: -40,
        isConnectable: true,
        observedAt: DateTime.now(),
      ),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(controller.state.status, ScanStatus.confirmingRisk);

    streamController.add([
      RadioScanResult(
        id: 'risk',
        name: 'AirPods Pro',
        rssi: -40,
        isConnectable: true,
        observedAt: DateTime.now(),
      ),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(controller.state.status, isNot(ScanStatus.possibleRiskDetected));

    streamController.add([
      RadioScanResult(
        id: 'risk',
        name: 'Ray-Ban Meta',
        rssi: -40,
        isConnectable: true,
        observedAt: DateTime.now(),
      ),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(controller.state.status, ScanStatus.confirmingRisk);

    await streamController.close();
    await controller.pauseProtection();
  });

  test('demo mode start sets isDemoMode true', () async {
    final controller = _controller(
      scanner: FakeRadioScanner(),
      runtime: _TestRuntime(const ScanPreflightResult.ok()),
      scannerMode: ScannerMode.demo,
    );

    await controller.startProtection();
    expect(controller.state.isDemoMode, isTrue);
    await controller.pauseProtection();
  });

  test('possible risk and other nearby signals are partitioned', () async {
    final streamController =
        StreamController<List<RadioScanResult>>.broadcast();
    final scanner = _StreamScanner(streamController.stream);
    final controller = _controller(
      scanner: scanner,
      runtime: _TestRuntime(const ScanPreflightResult.ok()),
      startupGraceDuration: Duration.zero,
      requiredElevatedScans: 1,
    );

    await controller.startProtection();
    streamController.add([
      RadioScanResult(
        id: 'risk',
        name: 'Ray-Ban Meta',
        rssi: -45,
        isConnectable: true,
        observedAt: DateTime.now(),
      ),
      RadioScanResult(
        id: 'audio',
        name: 'Headphones',
        rssi: -40,
        isConnectable: true,
        observedAt: DateTime.now(),
      ),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(controller.state.possibleRiskSignals, isNotEmpty);
    expect(
      controller.state.possibleRiskSignals.any(
        (s) => s.title.toLowerCase().contains('ray-ban'),
      ),
      isTrue,
    );
    expect(
      controller.state.otherNearbySignals.any(
        (s) => s.title.toLowerCase().contains('headphones'),
      ),
      isTrue,
    );

    await streamController.close();
    await controller.pauseProtection();
  });

  test('pauseProtection sets paused state', () async {
    final controller = _controller(
      scanner: FakeRadioScanner(),
      runtime: _TestRuntime(const ScanPreflightResult.ok()),
      scannerMode: ScannerMode.demo,
    );

    await controller.startProtection();
    controller.simulateHighRiskAlert();
    await controller.pauseProtection();

    expect(controller.state.status, ScanStatus.paused);
    expect(controller.state.protectionRequested, isFalse);
    expect(controller.state.riskLevel, RiskLevel.low);
    expect(controller.state.score, 0);
    expect(controller.state.possibleRiskSignals, isEmpty);
    expect(controller.state.otherNearbySignals, isEmpty);
  });
}

class _StreamScanner implements RadioScanner {
  _StreamScanner(this._stream);

  final Stream<List<RadioScanResult>> _stream;
  var _isScanning = false;

  @override
  bool get isScanning => _isScanning;

  @override
  Future<RadioStartResult> start() async {
    _isScanning = true;
    return RadioStarted(_stream);
  }

  @override
  Future<RadioStopResult> stop() async {
    if (!_isScanning) return RadioAlreadyStopped();
    _isScanning = false;
    return RadioStopped();
  }
}

class _CountingScanner extends _StreamScanner {
  _CountingScanner(super.stream);

  var startCallCount = 0;

  @override
  Future<RadioStartResult> start() async {
    startCallCount++;
    return super.start();
  }
}


