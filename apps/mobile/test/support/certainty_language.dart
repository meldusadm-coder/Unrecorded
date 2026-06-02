import 'package:flutter_test/flutter_test.dart';

const List<String> forbiddenCertaintyPhrases = [
  'recording detected',
  'confirmed threat',
  'spy detected',
  'surveillance found',
  'recording confirmed',
  'we know someone is recording',
  'device is recording',
  'definitely recording',
];

void expectNoCertaintyLanguage(String text) {
  final lower = text.toLowerCase();
  for (final phrase in forbiddenCertaintyPhrases) {
    if (phrase == 'device is recording' &&
        lower.contains('cannot prove that a device is recording')) {
      continue;
    }
    expect(lower, isNot(contains(phrase)));
  }
}
