import 'package:test/test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';

void main() {
  group('PrivacyDisclaimer', () {
    test('detection disclaimer is available and non-empty', () {
      expect(PrivacyDisclaimer.detectionDisclaimer, isNotEmpty);
    });

    test('detection disclaimer does not claim certainty', () {
      final text = PrivacyDisclaimer.detectionDisclaimer.toLowerCase();
      expect(text, isNot(contains('proves')));
      expect(text, isNot(contains('definitely')));
      expect(text, isNot(contains('certainly')));
      expect(text, contains('cannot prove'));
    });

    test('tagline uses cautious language', () {
      final text = PrivacyDisclaimer.tagline.toLowerCase();
      expect(text, contains('possible'));
      expect(text, contains('potential'));
    });

    test('privacy model mentions local processing', () {
      final text = PrivacyDisclaimer.privacyModel.toLowerCase();
      expect(text, contains('on your device'));
      expect(text, contains('no account'));
    });

    test('funding note is transparent', () {
      expect(PrivacyDisclaimer.fundingNote, isNotEmpty);
      expect(
        PrivacyDisclaimer.fundingNote.toLowerCase(),
        contains('privacy-respecting'),
      );
    });
  });
}
