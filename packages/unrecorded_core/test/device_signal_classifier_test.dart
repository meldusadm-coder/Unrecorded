import 'package:test/test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';

void main() {
  final classifier = DeviceSignalClassifier();

  test('classifies headphones as likely benign', () {
    final c = classifier.classify(
      DetectedSignal(
        id: 'fake:01',
        displayName: 'JBL Flip 6',
        rssi: -60,
        seenAt: DateTime(2025, 1, 1),
      ),
    );
    expect(c.category, DeviceSignalCategory.likelyAudio);
    expect(c.typeLabel, contains('unlikely recording'));
  });

  test('classifies smart glasses name as possible wearable', () {
    final c = classifier.classify(
      DetectedSignal(
        id: 'fake:02',
        displayName: 'Ray-Ban Meta',
        rssi: -45,
        seenAt: DateTime(2025, 1, 1),
        isConnectable: true,
      ),
    );
    expect(c.category, DeviceSignalCategory.possibleRecordingWearable);
    expect(c.relevanceScore, greaterThan(0));
  });

  test('unknown name stays unknown', () {
    final c = classifier.classify(
      DetectedSignal(
        id: 'opaque-uuid-1234',
        displayName: 'Unknown BLE',
        seenAt: DateTime(2025, 1, 1),
      ),
    );
    expect(c.category, DeviceSignalCategory.unknown);
  });

  test('MAC prefix can elevate unknown id to possible wearable hint', () {
    final c = classifier.classify(
      DetectedSignal(
        id: '00:0B:9A:12:34:56',
        seenAt: DateTime(2025, 1, 1),
      ),
    );
    expect(c.vendorHint, isNotNull);
    expect(c.category, DeviceSignalCategory.possibleRecordingWearable);
  });

  test('topAlertSignals excludes benign and ranks wearables first', () {
    final top = classifier.topAlertSignals([
      DetectedSignal(
        id: 'a',
        displayName: 'JBL Speaker',
        seenAt: DateTime(2025, 1, 1),
      ),
      DetectedSignal(
        id: 'b',
        displayName: 'Ray-Ban Meta',
        rssi: -40,
        seenAt: DateTime(2025, 1, 1),
        isConnectable: true,
      ),
    ]);
    expect(top, hasLength(1));
    expect(top.first.signal.displayName, 'Ray-Ban Meta');
  });

  test('idLabel distinguishes MAC from opaque id', () {
    expect(
      DeviceSignalClassifier.idLabel('AA:BB:CC:DD:EE:FF'),
      'Bluetooth address',
    );
    expect(
      DeviceSignalClassifier.idLabel('random-uuid'),
      'Device ID',
    );
  });
}
