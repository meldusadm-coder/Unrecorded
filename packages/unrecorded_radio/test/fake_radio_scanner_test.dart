import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_radio/unrecorded_radio.dart';

const _forbiddenWording = <String>[
  'recording detected',
  'confirmed threat',
  'spy detected',
  'surveillance found',
  'recording confirmed',
  'we know someone is recording',
  'device is recording',
];

void _expectNoCertaintyWording(String? text) {
  final lower = text?.toLowerCase() ?? '';
  for (final phrase in _forbiddenWording) {
    expect(lower, isNot(contains(phrase)));
  }
}

void main() {
  group('FakeRadioScanner', () {
    test('emits immediate first batch and periodic follow-up batches',
        () async {
      final scanner = FakeRadioScanner(
        scenario: FakeDemoScenario.low,
        random: Random(1),
        tickInterval: const Duration(milliseconds: 20),
      );
      addTearDown(scanner.stop);
      final batches = <List<RadioScanResult>>[];
      scanner.scan().listen(batches.add);

      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(batches, isNotEmpty, reason: 'first batch should be immediate');

      final firstCount = batches.length;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(
        batches.length,
        greaterThan(firstCount),
        reason: 'periodic batches should continue',
      );
    });

    test('all results include id and observedAt', () async {
      final scanner = FakeRadioScanner(
        scenario: FakeDemoScenario.low,
        random: Random(2),
        tickInterval: const Duration(milliseconds: 20),
      );
      addTearDown(scanner.stop);
      final first = await scanner.scan().first;
      for (final result in first) {
        expect(result.id, isNotEmpty);
        expect(result.observedAt, isNotNull);
      }
    });

    test('low scenario emits benign-only names', () async {
      final scanner = FakeRadioScanner(
        scenario: FakeDemoScenario.low,
        random: Random(3),
      );
      addTearDown(scanner.stop);
      final batch = await scanner.scan().first;
      expect(
        batch.any((r) => (r.name ?? '').toLowerCase().contains('meta')),
        isFalse,
      );
      expect(
        batch.any((r) => (r.name ?? '').toLowerCase().contains('ray-ban')),
        isFalse,
      );
      expect(batch.any((r) => (r.name ?? '').contains('JBL')), isTrue);
    });

    test(
        'medium scenario emits plausible medium risk signal with benign context',
        () async {
      final scanner = FakeRadioScanner(
        scenario: FakeDemoScenario.medium,
        random: Random(4),
      );
      addTearDown(scanner.stop);
      final batch = await scanner.scan().first;
      expect(batch.any((r) => r.name == 'Meta Smart Glasses'), isTrue);
      expect(batch.any((r) => r.name == 'JBL Flip 6'), isTrue);
      expect(batch.any((r) => r.name == 'AirPods Pro'), isTrue);
    });

    test('high scenario always includes Ray-Ban Meta style signal', () async {
      final scanner = FakeRadioScanner(
        scenario: FakeDemoScenario.high,
        random: Random(5),
      );
      addTearDown(scanner.stop);
      final batch = await scanner.scan().first;
      expect(batch.any((r) => r.name == 'Ray-Ban Meta'), isTrue);
    });

    test('random scenario emits valid deterministic-ish batches with seed',
        () async {
      final scanner = FakeRadioScanner(
        scenario: FakeDemoScenario.random,
        random: Random(99),
        tickInterval: const Duration(milliseconds: 20),
      );
      addTearDown(scanner.stop);
      final first = await scanner.scan().first;
      expect(first, isNotEmpty);
      expect(first.every((r) => r.id.isNotEmpty), isTrue);
      for (final result in first) {
        _expectNoCertaintyWording(result.name);
      }
    });

    test('highRiskBatch returns stable valid data', () {
      final now = DateTime(2025, 6, 1, 12, 0, 0);
      final batch = FakeRadioScanner.highRiskBatch(observedAt: now);
      expect(batch.map((r) => r.id), ['fake:aa:bb:cc:01', 'fake:dd:ee:ff:03']);
      expect(batch.every((r) => r.observedAt == now), isTrue);
      for (final result in batch) {
        _expectNoCertaintyWording(result.name);
      }
    });

    test('stop prevents further batch delivery', () async {
      final scanner = FakeRadioScanner(
        scenario: FakeDemoScenario.random,
        random: Random(6),
        tickInterval: const Duration(milliseconds: 20),
      );
      final batches = <List<RadioScanResult>>[];
      scanner.scan().listen(batches.add);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await scanner.stop();
      final countAfterStop = batches.length;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(batches.length, countAfterStop);
    });

    test('isScanning is true while scanning', () async {
      final scanner = FakeRadioScanner(
        scenario: FakeDemoScenario.low,
        random: Random(7),
      );
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
