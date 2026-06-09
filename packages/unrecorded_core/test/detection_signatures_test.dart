import 'package:test/test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';

void main() {
  group('detectionSignatures catalogue', () {
    test('every entry has required fields', () {
      expect(detectionSignatures, isNotEmpty);
      for (final signature in detectionSignatures) {
        expect(signature.id, isNotEmpty);
        expect(signature.brandFamily, isNotEmpty);
        expect(signature.confidenceWeight, inInclusiveRange(1, 100));
        expect(signature.matchExplanation, isNotEmpty);
        expect(
          signature.nameKeywords.isNotEmpty ||
              signature.serviceUuidHints.isNotEmpty ||
              signature.manufacturerIdHints.isNotEmpty ||
              signature.macPrefixHints.isNotEmpty,
          isTrue,
          reason: '${signature.id} must match on at least one field',
        );
        expect(
          signature.matchExplanation.toLowerCase(),
          isNot(contains('proof')),
        );
      }
    });

    test('ids are unique', () {
      final ids = detectionSignatures.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });
}
