import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_radio/unrecorded_radio.dart';

void main() {
  test('fakeDemoScenarioFromEnvironment maps known values', () {
    expect(
      fakeDemoScenarioFromEnvironment('high'),
      FakeDemoScenario.high,
    );
    expect(
      fakeDemoScenarioFromEnvironment(''),
      FakeDemoScenario.high,
    );
    expect(
      fakeDemoScenarioFromEnvironment('random'),
      FakeDemoScenario.random,
    );
  });
}
