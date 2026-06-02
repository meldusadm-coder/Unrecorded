import 'dart:math';

import 'package:unrecorded_radio/unrecorded_radio.dart';
import 'package:unrecorded_radio/unrecorded_radio_testing.dart';

import 'support/radio_scanner_contract.dart';

void main() {
  runRadioScannerContract('FakeRadioScanner', () {
    final scanner = FakeRadioScanner(
      scenario: FakeDemoScenario.low,
      random: Random(42),
      tickInterval: const Duration(milliseconds: 10),
    );
    return RadioScannerContractHarness(scanner: scanner);
  });

  runRadioScannerContract('ScriptedRadioScanner', () {
    final scanner = ScriptedRadioScanner();
    return RadioScannerContractHarness(
      scanner: scanner,
      emitBatch: (batch) async => scanner.emit(batch),
      emitError: (error) async => scanner.emitError(error),
      complete: () => scanner.complete(),
    );
  });
}
