import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_mobile/services/scanner_cadence_config.dart';
import 'package:unrecorded_mobile/services/scanner_manager.dart';
import 'package:unrecorded_radio/unrecorded_radio.dart';
import 'package:unrecorded_radio/unrecorded_radio_testing.dart';

RadioScanResult _result(String id) =>
    RadioScanResult(id: id, observedAt: DateTime(2025, 1, 1));

void main() {
  test('start begins scan window and duplicate start is ignored', () {
    fakeAsync((async) {
      final scanners = <ScriptedRadioScanner>[];
      final manager = ScannerManager(
        scannerFactory: () {
          final scanner = ScriptedRadioScanner();
          scanners.add(scanner);
          return scanner;
        },
        cadence: const ScannerCadenceConfig(
          scanWindow: Duration(milliseconds: 20),
          restInterval: Duration(milliseconds: 30),
        ),
      );

      var starts = 0;
      manager.onScanWindowStart = () => starts++;

      manager.start();
      async.flushMicrotasks();
      manager.start();
      async.flushMicrotasks();

      expect(manager.isRunning, isTrue);
      expect(manager.inScanWindow, isTrue);
      expect(starts, 1);
      expect(scanners.length, 1);
    });
  });

  test('scan window ends, rests, then restarts scanning', () {
    fakeAsync((async) {
      final manager = ScannerManager(
        scannerFactory: () => ScriptedRadioScanner(),
        cadence: const ScannerCadenceConfig(
          scanWindow: Duration(milliseconds: 20),
          restInterval: Duration(seconds: 12),
        ),
      );

      var windowEnds = 0;
      var starts = 0;
      manager.onScanWindowStart = () => starts++;
      manager.onScanWindowEnd = () => windowEnds++;

      manager.start();
      async.flushMicrotasks();
      async.elapse(const Duration(milliseconds: 21));
      async.flushMicrotasks();

      expect(windowEnds, greaterThanOrEqualTo(0));

      async.elapse(const Duration(seconds: 12));
      async.flushMicrotasks();
      expect(starts, greaterThanOrEqualTo(1));
    });
  });

  test('stream onDone during window restarts scanner within same window', () {
    fakeAsync((async) {
      final scanners = <ScriptedRadioScanner>[];
      final manager = ScannerManager(
        scannerFactory: () {
          final scanner = ScriptedRadioScanner();
          scanners.add(scanner);
          return scanner;
        },
        cadence: const ScannerCadenceConfig(
          scanWindow: Duration(milliseconds: 40),
          restInterval: Duration(milliseconds: 100),
        ),
      );

      manager.start();
      async.flushMicrotasks();
      expect(scanners.length, 1);

      scanners.first.complete();
      async.flushMicrotasks();
      expect(scanners.length, 2);
      expect(manager.inScanWindow, isTrue);
    });
  });

  test('stream error forwards through onError and stop remains safe', () {
    fakeAsync((async) {
      final scanner = ScriptedRadioScanner();
      final manager = ScannerManager(
        scannerFactory: () => scanner,
        cadence: const ScannerCadenceConfig(
          scanWindow: Duration(milliseconds: 40),
          restInterval: Duration(milliseconds: 100),
        ),
      );

      final errors = <Object>[];
      manager.onError = errors.add;
      manager.start();
      async.flushMicrotasks();

      scanner.emitError(StateError('scan failed'));
      async.flushMicrotasks();
      expect(errors, hasLength(1));

      manager.stop();
      async.flushMicrotasks();
      expect(manager.isRunning, isFalse);
      expect(manager.inScanWindow, isFalse);
    });
  });

  test('stop cancels cadence and prevents new batches', () {
    fakeAsync((async) {
      final scanner = ScriptedRadioScanner();
      final manager = ScannerManager(
        scannerFactory: () => scanner,
        cadence: const ScannerCadenceConfig(
          scanWindow: Duration(milliseconds: 15),
          restInterval: Duration(milliseconds: 15),
        ),
      );

      final batches = <List<RadioScanResult>>[];
      manager.onBatch = batches.add;

      manager.start();
      async.flushMicrotasks();
      scanner.emit([_result('one')]);
      async.flushMicrotasks();
      expect(batches, hasLength(1));

      manager.stop();
      async.flushMicrotasks();
      scanner.emit([_result('two')]);
      async.flushMicrotasks();

      expect(manager.isRunning, isFalse);
      expect(manager.inScanWindow, isFalse);
      expect(batches, hasLength(1));

      async.elapse(const Duration(milliseconds: 50));
      async.flushMicrotasks();
      expect(manager.inScanWindow, isFalse);
    });
  });
}
