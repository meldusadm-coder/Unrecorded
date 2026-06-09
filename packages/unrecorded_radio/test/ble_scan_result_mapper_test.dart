import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_radio/src/ble_scan_result_mapper.dart';

void main() {
  group('mapBleAdvertisement', () {
    test('maps id, rssi, connectable, and service UUIDs', () {
      final now = DateTime(2025, 6, 1, 12);
      final result = mapBleAdvertisement(
        const BleAdvertisement(
          id: 'AA:BB:CC:DD:EE:FF',
          advertisedName: 'Ray-Ban Meta',
          platformName: 'Platform Name',
          rssi: -47,
          serviceUuids: ['180A', '180F'],
          isConnectable: true,
        ),
        observedAt: now,
      );

      expect(result.id, 'AA:BB:CC:DD:EE:FF');
      expect(result.name, 'Ray-Ban Meta');
      expect(result.rssi, -47);
      expect(result.serviceUuids, ['180A', '180F']);
      expect(result.isConnectable, isTrue);
      expect(result.observedAt, now);
    });

    test('prefers advertised name over platform name', () {
      final result = mapBleAdvertisement(
        const BleAdvertisement(
          id: 'id',
          advertisedName: 'Advertised Name',
          platformName: 'Platform Name',
        ),
      );
      expect(result.name, 'Advertised Name');
    });

    test('falls back to platform name when advertised is blank', () {
      final result = mapBleAdvertisement(
        const BleAdvertisement(
          id: 'id',
          advertisedName: '  ',
          platformName: 'Platform Name',
        ),
      );
      expect(result.name, 'Platform Name');
    });

    test('returns null when both names are blank or missing', () {
      final missing = mapBleAdvertisement(const BleAdvertisement(id: 'id1'));
      final blank = mapBleAdvertisement(
        const BleAdvertisement(
          id: 'id2',
          advertisedName: '   ',
          platformName: '',
        ),
      );
      expect(missing.name, isNull);
      expect(blank.name, isNull);
    });

    test('maps manufacturer company IDs without payloads', () {
      final result = mapBleAdvertisement(
        const BleAdvertisement(
          id: 'id',
          manufacturerIds: [0x004C, 0x0075],
        ),
      );
      expect(result.manufacturerIds, [0x004C, 0x0075]);
    });

    test('handles null-like optional fields safely', () {
      final result = mapBleAdvertisement(const BleAdvertisement(id: 'id'));
      expect(result.rssi, isNull);
      expect(result.serviceUuids, isEmpty);
      expect(result.manufacturerIds, isEmpty);
      expect(result.isConnectable, isFalse);
    });

    test('duplicate IDs are preserved as-is across multiple maps', () {
      final first = mapBleAdvertisement(const BleAdvertisement(id: 'dup'));
      final second = mapBleAdvertisement(const BleAdvertisement(id: 'dup'));
      expect(first.id, 'dup');
      expect(second.id, 'dup');
    });
  });
}
