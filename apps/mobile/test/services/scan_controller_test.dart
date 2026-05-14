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
