import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_mobile/features/scan/scan_state.dart';
import 'package:unrecorded_mobile/services/scan_runtime.dart';
import 'package:unrecorded_mobile/services/scanner_provider.dart';
import 'package:unrecorded_radio/unrecorded_radio.dart';

class _TestRuntime extends ScanRuntime {
  _TestRuntime(this.result);

  final ScanPreflightResult result;

  @override
  bool get isAndroid => true;

  @override
  Future<ScanPreflightResult> ensureAndroidReady() async => result;
}

class _DelayedRuntime extends ScanRuntime {
  _DelayedRuntime(this.delay, this.result);

  final Duration delay;
  final ScanPreflightResult result;
  int calls = 0;

  @override
  bool get isAndroid => true;

  @override
  Future<ScanPreflightResult> ensureAndroidReady() async {
    calls += 1;
    await Future<void>.delayed(delay);
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('startProtection sets permissionRequired when preflight fails', () async {
    final controller = ScanController(
      scanner: FakeRadioScanner(),
      runtime: _TestRuntime(
        const ScanPreflightResult.fail(ScanPreflightFailure.permissionDenied),
      ),
      scannerMode: ScannerMode.auto,
      scoringEngine: RiskScoringEngine(),
    );

    await controller.startProtection(persist: false);

    expect(controller.state.status, ScanStatus.permissionRequired);
    expect(controller.state.protectionEnabled, isTrue);
  });

  test('startProtection transitions to scanning when preflight succeeds',
      () async {
    final streamController =
        StreamController<List<RadioScanResult>>.broadcast();
    final scanner = _StreamScanner(streamController.stream);
    final controller = ScanController(
      scanner: scanner,
      runtime: _TestRuntime(const ScanPreflightResult.ok()),
      scannerMode: ScannerMode.auto,
      scoringEngine: RiskScoringEngine(),
    );

    await controller.startProtection(persist: false);

    expect(controller.state.status, ScanStatus.scanning);
    await streamController.close();
  });

  test('startProtection sets permissionRequired for bluetoothUnsupported',
      () async {
    final controller = ScanController(
      scanner: FakeRadioScanner(),
      runtime: _TestRuntime(
        const ScanPreflightResult.fail(
          ScanPreflightFailure.bluetoothUnsupported,
        ),
      ),
      scannerMode: ScannerMode.auto,
      scoringEngine: RiskScoringEngine(),
    );

    await controller.startProtection(persist: false);

    expect(controller.state.status, ScanStatus.permissionRequired);
  });

  test('scan stream error sets error state', () async {
    final streamController =
        StreamController<List<RadioScanResult>>.broadcast();
    final scanner = _StreamScanner(streamController.stream);
    final controller = ScanController(
      scanner: scanner,
      runtime: _TestRuntime(const ScanPreflightResult.ok()),
      scannerMode: ScannerMode.auto,
      scoringEngine: RiskScoringEngine(),
    );

    await controller.startProtection(persist: false);
    streamController.addError(Exception('boom'));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(controller.state.status, ScanStatus.error);
    await streamController.close();
  });

  test('stream done restarts scan while protection enabled', () async {
    final streamController =
        StreamController<List<RadioScanResult>>.broadcast();
    final scanner = _RestartScanner(streamController);
    final controller = ScanController(
      scanner: scanner,
      runtime: _TestRuntime(const ScanPreflightResult.ok()),
      scannerMode: ScannerMode.auto,
      scoringEngine: RiskScoringEngine(),
    );

    await controller.startProtection(persist: false);
    await streamController.close();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await controller.pauseProtection(persist: false);

    expect(scanner.restartCount, greaterThanOrEqualTo(1));
    expect(controller.state.status, ScanStatus.paused);
  });

  test('high risk results set possibleRiskDetected', () async {
    final streamController =
        StreamController<List<RadioScanResult>>.broadcast();
    final scanner = _StreamScanner(streamController.stream);
    final controller = ScanController(
      scanner: scanner,
      runtime: _TestRuntime(const ScanPreflightResult.ok()),
      scannerMode: ScannerMode.auto,
      scoringEngine: RiskScoringEngine(),
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
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(controller.state.status, ScanStatus.possibleRiskDetected);
    expect(controller.state.lastCheckedAt, isNotNull);
    await streamController.close();
  });

  test('pauseProtection sets paused state', () async {
    final controller = ScanController(
      scanner: FakeRadioScanner(),
      runtime: _TestRuntime(const ScanPreflightResult.ok()),
      scannerMode: ScannerMode.demo,
      scoringEngine: RiskScoringEngine(),
    );

    await controller.startProtection(persist: false);
    await controller.pauseProtection(persist: false);

    expect(controller.state.status, ScanStatus.paused);
    expect(controller.state.protectionEnabled, isFalse);
  });

  test('re-entrant startProtection during preflight is ignored', () async {
    final runtime = _DelayedRuntime(
      const Duration(milliseconds: 50),
      const ScanPreflightResult.ok(),
    );
    final streamController =
        StreamController<List<RadioScanResult>>.broadcast();
    final scanner = _StreamScanner(streamController.stream);
    final controller = ScanController(
      scanner: scanner,
      runtime: runtime,
      scannerMode: ScannerMode.auto,
      scoringEngine: RiskScoringEngine(),
    );

    final first = controller.startProtection(persist: false);
    final second = controller.startProtection(persist: false);

    await Future.wait([first, second]);

    expect(runtime.calls, 1);
    await streamController.close();
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

class _RestartScanner implements RadioScanner {
  _RestartScanner(this._controller);

  final StreamController<List<RadioScanResult>> _controller;
  int restartCount = 0;

  @override
  bool get isScanning => true;

  @override
  Stream<List<RadioScanResult>> scan() {
    restartCount++;
    return _controller.stream;
  }

  @override
  Future<void> stop() async {}
}
