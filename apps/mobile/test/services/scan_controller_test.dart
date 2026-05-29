import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_mobile/features/scan/scan_state.dart';
import 'package:unrecorded_mobile/services/scan_lifecycle_coordinator.dart';
import 'package:unrecorded_mobile/services/scan_runtime.dart';
import 'package:unrecorded_mobile/services/scanner_cadence_config.dart';
import 'package:unrecorded_mobile/services/scanner_provider.dart';
import 'package:unrecorded_mobile/services/signal_ui_mapper.dart';
import 'package:unrecorded_radio/unrecorded_radio.dart';

class _TestRuntime extends ScanRuntime {
  _TestRuntime(this.result);

  final ScanPreflightResult result;

  @override
  bool get isAndroid => true;

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

    await controller.startProtection(persist: false);

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

    await controller.startProtection(persist: false);

    expect(controller.state.status, ScanStatus.scanning);
    await streamController.close();
    await controller.pauseProtection(persist: false);
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

    await controller.startProtection(persist: false);

    expect(controller.state.status, ScanStatus.bluetoothUnsupported);
  });

  test('scan stream error sets error state', () async {
    final streamController =
        StreamController<List<RadioScanResult>>.broadcast();
    final scanner = _StreamScanner(streamController.stream);
    final controller = _controller(
      scanner: scanner,
      runtime: _TestRuntime(const ScanPreflightResult.ok()),
    );

    await controller.startProtection(persist: false);
    streamController.addError(Exception('boom'));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(controller.state.status, ScanStatus.error);
    await streamController.close();
    await controller.pauseProtection(persist: false);
  });

  test('high risk results set possibleRiskDetected', () async {
    final streamController =
        StreamController<List<RadioScanResult>>.broadcast();
    final scanner = _StreamScanner(streamController.stream);
    final controller = _controller(
      scanner: scanner,
      runtime: _TestRuntime(const ScanPreflightResult.ok()),
    );

    await controller.startProtection(persist: false);

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
    await controller.pauseProtection(persist: false);
  });

  test('scan window end does not count cached elevation toward alert', () async {
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

    await controller.startProtection(persist: false);

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
    await controller.pauseProtection(persist: false);
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

    await controller.startProtection(persist: false);

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
    await controller.pauseProtection(persist: false);
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

    await controller.startProtection(persist: false);

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
    await controller.pauseProtection(persist: false);
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

  test('pauseProtection sets paused state', () async {
    final controller = _controller(
      scanner: FakeRadioScanner(),
      runtime: _TestRuntime(const ScanPreflightResult.ok()),
      scannerMode: ScannerMode.demo,
    );

    await controller.startProtection(persist: false);
    await controller.pauseProtection(persist: false);

    expect(controller.state.status, ScanStatus.paused);
    expect(controller.state.protectionRequested, isFalse);
  });
}

class _StreamScanner implements RadioScanner {
  _StreamScanner(this._stream);

  final Stream<List<RadioScanResult>> _stream;

  @override
  bool get isScanning => true;

  @override
  Stream<List<RadioScanResult>> scan() => _stream;

  @override
  Future<void> stop() async {}
}
