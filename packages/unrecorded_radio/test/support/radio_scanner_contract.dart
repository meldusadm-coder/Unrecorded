import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_radio/unrecorded_radio.dart';

class RadioScannerContractHarness {
  const RadioScannerContractHarness({
    required this.scanner,
    this.emitBatch,
    this.emitError,
    this.complete,
  });

  final RadioScanner scanner;
  final Future<void> Function(List<RadioScanResult> batch)? emitBatch;
  final Future<void> Function(Object error)? emitError;
  final Future<void> Function()? complete;
}

void runRadioScannerContract(
  String name,
  RadioScannerContractHarness Function() createHarness,
) {
  group('RadioScanner contract: $name', () {
    test('isScanning false before scan and stop safe when idle', () async {
      final harness = createHarness();
      expect(harness.scanner.isScanning, isFalse);
      await harness.scanner.stop();
      expect(harness.scanner.isScanning, isFalse);
    });

    test('scan starts emission and isScanning becomes true', () async {
      final harness = createHarness();
      final firstBatch = Completer<List<RadioScanResult>>();
      final sub = harness.scanner.scan().listen((batch) {
        if (!firstBatch.isCompleted) firstBatch.complete(batch);
      });
      if (harness.emitBatch != null) {
        await harness.emitBatch!([
          RadioScanResult(id: 'device:1', observedAt: DateTime(2025, 1, 1)),
        ]);
      }
      await firstBatch.future.timeout(const Duration(seconds: 2));
      expect(harness.scanner.isScanning, isTrue);
      await sub.cancel();
      await harness.scanner.stop();
    });

    test('after stop no further batches are delivered', () async {
      final harness = createHarness();
      final received = <List<RadioScanResult>>[];
      final sub = harness.scanner.scan().listen(received.add);

      if (harness.emitBatch != null) {
        await harness.emitBatch!([
          RadioScanResult(id: 'device:1', observedAt: DateTime(2025, 1, 1)),
        ]);
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      final beforeStopCount = received.length;
      await harness.scanner.stop();
      expect(harness.scanner.isScanning, isFalse);

      if (harness.emitBatch != null) {
        await harness.emitBatch!([
          RadioScanResult(id: 'device:2', observedAt: DateTime(2025, 1, 1)),
        ]);
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(received.length, beforeStopCount);
      expect(sub.isPaused, isFalse);
    });

    test('subscription cancel stops scanning', () async {
      final harness = createHarness();
      final sub = harness.scanner.scan().listen((_) {});
      if (harness.emitBatch != null) {
        await harness.emitBatch!([
          RadioScanResult(id: 'device:1', observedAt: DateTime(2025, 1, 1)),
        ]);
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await sub.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(harness.scanner.isScanning, isFalse);
    });

    test('repeated start stop does not leak scanner state', () async {
      final harness = createHarness();
      for (var i = 0; i < 2; i++) {
        final sub = harness.scanner.scan().listen((_) {});
        if (harness.emitBatch != null) {
          await harness.emitBatch!([
            RadioScanResult(id: 'device:$i', observedAt: DateTime(2025, 1, 1)),
          ]);
        }
        await sub
            .cancel()
            .timeout(const Duration(seconds: 2), onTimeout: () {});
        await harness.scanner.stop();
        expect(harness.scanner.isScanning, isFalse);
      }
    });

    test('supports empty batches and duplicate device IDs', () async {
      final harness = createHarness();
      final received = <List<RadioScanResult>>[];
      harness.scanner.scan().listen(received.add);

      if (harness.emitBatch != null) {
        await harness.emitBatch!(const []);
        await harness.emitBatch!([
          RadioScanResult(id: 'dup', observedAt: DateTime(2025, 1, 1)),
          RadioScanResult(id: 'dup', observedAt: DateTime(2025, 1, 1)),
        ]);
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      expect(received, isNotEmpty);
      await harness.scanner.stop();
    });

    test('can surface stream errors in controlled scanners', () async {
      final harness = createHarness();
      if (harness.emitError == null) return;

      final errors = <Object>[];
      harness.scanner.scan().listen((_) {}, onError: errors.add);
      await harness.emitError!(StateError('simulated scan error'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(errors, isNotEmpty);
      await harness.scanner.stop();
    });

    test('stream completion can be handled in controlled scanners', () async {
      final harness = createHarness();
      if (harness.complete == null) return;

      var done = false;
      harness.scanner.scan().listen((_) {}, onDone: () => done = true);
      await harness.complete!();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(done, isTrue);
      expect(harness.scanner.isScanning, isFalse);
    });
  });
}
