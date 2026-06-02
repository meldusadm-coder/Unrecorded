/// Scripted fake-scan behaviour for demos, emulator UAT, and tests.
enum FakeDemoScenario {
  /// Varies batches (legacy behaviour).
  random,

  /// Only benign device names; risk stays low.
  low,

  /// Suspicious-sounding device name at weak signal — typically scores medium risk.
  medium,

  /// Suspicious smart-glasses-style name every batch.
  high,
}

/// Parses [UNRECORDED_DEMO_SCENARIO] (`random`, `low`, `medium`, `high`).
FakeDemoScenario fakeDemoScenarioFromEnvironment([
  String value = const String.fromEnvironment(
    'UNRECORDED_DEMO_SCENARIO',
    defaultValue: '',
  ),
]) {
  switch (value.toLowerCase()) {
    case 'low':
      return FakeDemoScenario.low;
    case 'medium':
      return FakeDemoScenario.medium;
    case 'high':
      return FakeDemoScenario.high;
    case 'random':
      return FakeDemoScenario.random;
    default:
      return FakeDemoScenario.high;
  }
}
