import 'package:flutter_test/flutter_test.dart';

const List<String> _forbiddenCertaintyPhrases = [
  'recording detected',
  'confirmed threat',
  'spy detected',
  'surveillance found',
  'recording confirmed',
  'we know someone is recording',
  'device is recording',
  'definitely recording',
];

void expectNoCertaintyLanguage(String? text) {
  final lower = text?.toLowerCase() ?? '';
  for (final phrase in _forbiddenCertaintyPhrases) {
    expect(lower, isNot(contains(phrase)));
  }
}
