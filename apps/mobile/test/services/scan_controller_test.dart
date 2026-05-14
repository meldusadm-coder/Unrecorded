import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_mobile/features/scan/scan_state.dart';
import 'package:unrecorded_mobile/services/scan_runtime.dart';
import 'package:unrecorded_mobile/services/scanner_provider.dart';
import 'package:unrecorded_radio/unrecorded_radio.dart';

class _TestRuntime extends ScanRuntime {
  _TestRuntime(this.result, {this.android = true});

  final ScanPreflightResult result;
  final bool android;

  @override
  bool get isAndroid => android;

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
  test('startScan sets permissionDenied state when preflight fails', () async {
    final controller = ScanController(
      scanner: FakeRadioScanner(),
      runtime: _TestRuntime(
        const ScanPreflightResult.fail(ScanPreflightFailure.permissionDenied),
      ),
      scannerMode: ScannerMode.auto,
      scoringEngine: RiskScoringEngine(),
    );

    await controller.startScan();

    expect(controller.state.status, ScanStatus.permissionDenied);
  });

  test('startScan transitions to scanning when preflight succeeds', () async {
    final streamController = StreamController<List<RadioScanResult>>();
    final scanner = _StreamScanner(streamController.stream);
    final controller = ScanController(
      scanner: scanner,
      runtime: _TestRuntime(const ScanPreflightResult.ok()),
      scannerMode: ScannerMode.auto,
      scoringEngine: RiskScoringEngine(),
    );

    await controller.startScan();

    expect(controller.state.status, ScanStatus.scanning);
    await streamController.close();
  });

  test('startScan sets bluetoothUnsupported state', () async {
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

    await controller.startScan();

    expect(controller.state.status, ScanStatus.bluetoothUnsupported);
  });

  test('startScan sets bluetoothOff state', () async {
    final controller = ScanController(
      scanner: FakeRadioScanner(),
      runtime: _TestRuntime(
        const ScanPreflightResult.fail(ScanPreflightFailure.bluetoothOff),
      ),
      scannerMode: ScannerMode.auto,
      scoringEngine: RiskScoringEngine(),
    );

    await controller.startScan();

    expect(controller.state.status, ScanStatus.bluetoothOff);
  });

  test('scan stream error sets error state', () async {
    final streamController = StreamController<List<RadioScanResult>>();
    final scanner = _StreamScanner(streamController.stream);
    final controller = ScanController(
      scanner: scanner,
      runtime: _TestRuntime(const ScanPreflightResult.ok()),
      scannerMode: ScannerMode.auto,
      scoringEngine: RiskScoringEngine(),
    );

    await controller.startScan();
    streamController.addError(Exception('boom'));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(controller.state.status, ScanStatus.error);
    await streamController.close();
  });

  test('scan stream done sets timedOut state', () async {
    final streamController = StreamController<List<RadioScanResult>>();
    final scanner = _StreamScanner(streamController.stream);
    final controller = ScanController(
      scanner: scanner,
      runtime: _TestRuntime(const ScanPreflightResult.ok()),
      scannerMode: ScannerMode.auto,
      scoringEngine: RiskScoringEngine(),
    );

    await controller.startScan();
    await streamController.close();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(controller.state.status, ScanStatus.timedOut);
  });

  test('re-entrant startScan during preflight is ignored', () async {
    final runtime =
        _DelayedRuntime(const Duration(milliseconds: 50), const ScanPreflightResult.ok());
    final streamController = StreamController<List<RadioScanResult>>();
    final scanner = _StreamScanner(streamController.stream);
    final controller = ScanController(
      scanner: scanner,
      runtime: runtime,
      scannerMode: ScannerMode.auto,
      scoringEngine: RiskScoringEngine(),
    );

    final first = controller.startScan();
    final second = controller.startScan();

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
