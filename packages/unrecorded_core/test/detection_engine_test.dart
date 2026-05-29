import 'package:test/test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';

TrackedSignal _tracked({
  required String id,
  String? name,
  int sightings = 1,
  int? rssi,
}) {
  final session = ScanSession();
  final now = DateTime(2025, 1, 1);
  for (var i = 0; i < sightings; i++) {
    session.observe(
      DetectedSignal(
        id: id,
        displayName: name,
        rssi: rssi,
        seenAt: now.add(Duration(seconds: i)),
      ),
    );
  }
  return session.activeSignals(now.add(Duration(seconds: sightings))).single;
}

void main() {
  final engine = DetectionEngine();

  test('Ray-Ban name is possible wearable with name evidence', () {
    final a =
        engine.assessAll([_tracked(id: 'x', name: 'Ray-Ban Meta')]).single;
    expect(a.category, DeviceSignalCategory.possibleRecordingWearable);
    expect(a.contributesToRisk, isTrue);
    expect(
      a.evidence.any((e) => e.kind == DetectionEvidenceKind.nameMatch),
      isTrue,
    );
  });

  test('AirPods classified as likely audio not risk', () {
    final a = engine.assessAll([_tracked(id: 'a', name: 'AirPods Pro')]).single;
    expect(a.category, DeviceSignalCategory.likelyAudio);
    expect(a.contributesToRisk, isFalse);
  });

  test('MetaLab Keyboard is input not Meta glasses', () {
    final a =
        engine.assessAll([_tracked(id: 'k', name: 'MetaLab Keyboard')]).single;
    expect(a.category, DeviceSignalCategory.likelyInput);
    expect(a.contributesToRisk, isFalse);
  });

  test('smart glasses name wins over broad benign terms', () {
    final a = engine
        .assessAll([_tracked(id: 'g', name: 'My Smart Glasses watch')]).single;
    expect(a.category, DeviceSignalCategory.possibleRecordingWearable);
    expect(a.contributesToRisk, isTrue);
  });

  test('repeated sighting adds evidence for matched signal', () {
    final a = engine.assessAll([
      _tracked(id: 'm', name: 'Ray-Ban Stories', sightings: 3),
    ]).single;
    expect(
      a.evidence.any((e) => e.kind == DetectionEvidenceKind.repeatedSighting),
      isTrue,
    );
  });
}
