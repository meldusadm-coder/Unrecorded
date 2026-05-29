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

    test('matches MAC prefix when name is missing', () {
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
}
