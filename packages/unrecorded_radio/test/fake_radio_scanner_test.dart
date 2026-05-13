import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_radio/unrecorded_radio.dart';

void main() {
  group('FakeRadioScanner', () {
    late FakeRadioScanner scanner;

    setUp(() {
      scanner = FakeRadioScanner();
    });

    tearDown(() async {
      await scanner.stop();
    });

    test('emits at least one batch', () async {
      final completer = Completer<List<RadioScanResult>>();
      final stream = scanner.scan();
      final sub = stream.listen((batch) {
        if (!completer.isCompleted) completer.complete(batch);
      });

      final first = await completer.future.timeout(
        const Duration(seconds: 10),
      );
      expect(first, isNotEmpty);

      await sub.cancel();
    });

    test('results contain valid fields', () async {
      final completer = Completer<List<RadioScanResult>>();
      final stream = scanner.scan();
      final sub = stream.listen((batch) {
        if (!completer.isCompleted) completer.complete(batch);
      });

      final batch = await completer.future.timeout(
        const Duration(seconds: 10),
      );

      for (final result in batch) {
        expect(result.id, isNotEmpty);
        expect(result.observedAt, isNotNull);
      }

      await sub.cancel();
    });

    test('isScanning is true while scanning', () async {
      expect(scanner.isScanning, isFalse);

      final stream = scanner.scan();
      final sub = stream.listen((_) {});

      expect(scanner.isScanning, isTrue);

      await sub.cancel();
      await scanner.stop();
      expect(scanner.isScanning, isFalse);
    });
  });
}
