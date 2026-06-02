import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_radio/unrecorded_radio.dart';

void main() {
  test('fakeDemoScenarioFromEnvironment maps known values', () {
    expect(fakeDemoScenarioFromEnvironment('low'), FakeDemoScenario.low);
    expect(fakeDemoScenarioFromEnvironment('medium'), FakeDemoScenario.medium);
    expect(fakeDemoScenarioFromEnvironment('high'), FakeDemoScenario.high);
    expect(fakeDemoScenarioFromEnvironment('random'), FakeDemoScenario.random);
  });

  test('fakeDemoScenarioFromEnvironment defaults invalid/empty to high', () {
    expect(fakeDemoScenarioFromEnvironment(''), FakeDemoScenario.high);
    expect(fakeDemoScenarioFromEnvironment('unknown'), FakeDemoScenario.high);
  });
}
