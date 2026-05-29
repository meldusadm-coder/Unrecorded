import 'package:test/test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';

void main() {
  group('ScanSession', () {
    late ScanSession session;
    final t0 = DateTime(2025, 1, 1, 12, 0, 0);

    setUp(() {
      session = ScanSession(staleTtl: const Duration(seconds: 60));
    });

    DetectedSignal signal({
      required String id,
      String? name,
      int? rssi,
      DateTime? seenAt,
    }) {
      return DetectedSignal(
        id: id,
        displayName: name,
        rssi: rssi,
        seenAt: seenAt ?? t0,
      );
    }

    test('merges same id across batches', () {
      session.observe(signal(id: 'aa:bb:cc:dd:ee:ff', name: 'Ray-Ban Meta'));
      session.observe(
        signal(
          id: 'aa:bb:cc:dd:ee:ff',
          name: 'Ray-Ban Meta',
          rssi: -50,
          seenAt: t0.add(const Duration(seconds: 3)),
        ),
      );

      final active = session.activeSignals(t0.add(const Duration(seconds: 3)));
      expect(active, hasLength(1));
      expect(active.first.sightingCount, 2);
      expect(active.first.lastRssi, -50);
    });

    test('tracks firstSeenAt and lastSeenAt', () {
      final first = t0;
      final second = t0.add(const Duration(seconds: 10));
      session.observe(signal(id: 'device-1', seenAt: first));
      session.observe(signal(id: 'device-1', seenAt: second));

      final tracked = session.activeSignals(second).single;
      expect(tracked.firstSeenAt, first);
      expect(tracked.lastSeenAt, second);
    });

    test('does not merge unnamed unknown devices by name alone', () {
      session.observe(signal(id: 'random-id-1'));
      session.observe(signal(id: 'random-id-2'));

      expect(session.activeSignals(t0), hasLength(2));
    });

    test('merges service UUIDs and connectable flag', () {
      session.observe(
        DetectedSignal(
          id: 'dev-1',
          serviceIds: const ['uuid-a'],
          seenAt: t0,
          isConnectable: false,
        ),
      );
      session.observe(
        DetectedSignal(
          id: 'dev-1',
          serviceIds: const ['uuid-b'],
          seenAt: t0.add(const Duration(seconds: 1)),
          isConnectable: true,
        ),
      );

      final tracked =
          session.activeSignals(t0.add(const Duration(seconds: 1))).single;
      expect(tracked.serviceIds, containsAll(['uuid-a', 'uuid-b']));
      expect(tracked.everConnectable, isTrue);
    });

    test('expires stale signals after TTL', () {
      session.observe(signal(id: 'stale-device', seenAt: t0));
      final later = t0.add(const Duration(seconds: 61));
      final active = session.activeSignals(later);
      expect(active, isEmpty);
    });

    test('expireStale returns removed keys', () {
      session.observe(signal(id: 'gone', seenAt: t0));
      final expired = session.expireStale(t0.add(const Duration(seconds: 61)));
      expect(expired, contains('gone'));
      expect(session.count, 0);
    });

    test('reset clears session', () {
      session.observe(signal(id: 'a'));
      session.reset();
      expect(session.count, 0);
    });

    test('smoothes RSSI with EMA', () {
      session.observe(signal(id: 'rssi-dev', rssi: -80, seenAt: t0));
      session.observe(
        signal(
          id: 'rssi-dev',
          rssi: -50,
          seenAt: t0.add(const Duration(seconds: 1)),
        ),
      );
      final tracked =
          session.activeSignals(t0.add(const Duration(seconds: 1))).single;
      expect(tracked.smoothedRssi, isNotNull);
      expect(tracked.smoothedRssi!, greaterThan(-80));
      expect(tracked.smoothedRssi!, lessThan(-50));
    });
  });
}
