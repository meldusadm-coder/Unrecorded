import 'package:test/test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';

void main() {
  const matcher = SignatureMatcher();

  group('SignatureMatcher', () {
    test('matches known brand names', () {
      final match = matcher.bestMatch(
        DetectedSignal(
          id: 'aa:bb:cc:dd:ee:ff',
          displayName: 'Ray-Ban Meta',
          seenAt: DateTime(2025, 1, 1),
        ),
      );
      expect(match, isNotNull);
      expect(match!.signature.brandFamily, contains('Meta'));
      expect(match.kind, SignatureMatchKind.name);
    });

    test('does not match benign headphone names', () {
      expect(
        matcher.bestMatch(
          DetectedSignal(
            id: 'aa:bb:cc:dd:ee:ff',
            displayName: 'JBL Flip 6',
            seenAt: DateTime(2025, 1, 1),
          ),
        ),
        isNull,
      );
    });

    test('generic camera name scores lower than brand match', () {
      final brand = matcher.bestMatch(
        DetectedSignal(
          id: '1',
          displayName: 'Ray-Ban Stories',
          seenAt: DateTime(2025, 1, 1),
        ),
      );
      final generic = matcher.bestMatch(
        DetectedSignal(
          id: '2',
          displayName: 'Camera Glasses Pro',
          seenAt: DateTime(2025, 1, 1),
        ),
      );
      expect(brand!.score, greaterThan(generic!.score));
    });

    test('standalone meta word does not match removed broad keyword', () {
      expect(
        matcher.bestMatch(
          DetectedSignal(
            id: '3',
            displayName: 'MetaLab Keyboard',
            seenAt: DateTime(2025, 1, 1),
          ),
        ),
        isNull,
      );
    });

    test('matches address prefix when name is missing', () {
      final match = matcher.bestMatch(
        DetectedSignal(
          id: '00:0B:9A:12:34:56',
          seenAt: DateTime(2025, 1, 1),
        ),
      );
      expect(match, isNotNull);
      expect(match!.kind, SignatureMatchKind.macPrefix);
      expect(match.score, greaterThanOrEqualTo(15));
    });

    test('ignores address prefix on locally administered MAC', () {
      expect(
        matcher.bestMatch(
          DetectedSignal(
            id: 'F2:0B:9A:12:34:56',
            seenAt: DateTime(2025, 1, 1),
          ),
        ),
        isNull,
      );
    });

    test('matches manufacturer ID hint', () {
      const mfgMatcher = SignatureMatcher(
        signatures: [
          DetectionSignature(
            id: 'test-mfg',
            brandFamily: 'Test Glasses',
            manufacturerIdHints: [0x1234],
            confidenceWeight: 30,
            matchExplanation:
                'A nearby device may match Test Glasses via a manufacturer hint.',
          ),
        ],
      );
      final match = mfgMatcher.bestMatch(
        DetectedSignal(
          id: 'opaque',
          manufacturerIds: [0x1234],
          seenAt: DateTime(2025, 1, 1),
        ),
      );
      expect(match, isNotNull);
      expect(match!.kind, SignatureMatchKind.manufacturer);
    });

    test('matches normalized service UUID hints', () {
      const uuidMatcher = SignatureMatcher(
        signatures: [
          DetectionSignature(
            id: 'test-uuid-brand',
            brandFamily: 'Test Glasses',
            serviceUuidHints: ['fe26'],
            confidenceWeight: 30,
            matchExplanation:
                'A nearby device may match Test Glasses via a service hint.',
          ),
        ],
      );
      final match = uuidMatcher.bestMatch(
        DetectedSignal(
          id: 'opaque',
          serviceIds: ['0000fe26-0000-1000-8000-00805f9b34fb'],
          seenAt: DateTime(2025, 1, 1),
        ),
      );
      expect(match, isNotNull);
      expect(match!.kind, SignatureMatchKind.serviceUuid);
      expect(match.score, 30);
    });

    test('vendorHintFromId returns cautious prefix hint', () {
      final hint = matcher.vendorHintFromId('00:0B:9A:12:34:56');
      expect(hint, isNotNull);
      expect(hint!.toLowerCase(), contains('not proof'));
    });
  });

  group('false positive regression via DetectionEngine', () {
    final engine = DetectionEngine();

    DetectionAssessment assess(String name, {String id = 'fp-id'}) {
      final session = ScanSession();
      session.observe(
        DetectedSignal(id: id, displayName: name, seenAt: DateTime(2025, 1, 1)),
      );
      return engine
          .assessAll(session.activeSignals(DateTime(2025, 1, 1)))
          .single;
    }

    final safeNames = [
      'AirPods Pro',
      'Galaxy Buds',
      'Sony WH-1000XM5',
      'Bose QuietComfort',
      'JBL Flip 6',
      'Logitech Keyboard',
      'Garmin Forerunner',
      'Fitbit Charge',
      'Samsung Smart TV',
      'Roku Streaming Stick',
    ];

    for (final name in safeNames) {
      test('$name does not contribute to risk', () {
        final a = assess(name, id: 'safe-$name');
        expect(a.contributesToRisk, isFalse);
      });
    }

    test('Ray-Ban Meta still contributes to risk', () {
      final a = assess('Ray-Ban Meta', id: 'risk-1');
      expect(a.contributesToRisk, isTrue);
    });

    test('MetaLab Keyboard does not match Meta glasses', () {
      final a = assess('MetaLab Keyboard', id: 'kbd-1');
      expect(a.contributesToRisk, isFalse);
    });
  });
}
