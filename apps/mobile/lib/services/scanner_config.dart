import 'package:flutter/foundation.dart';
import 'package:unrecorded_radio/unrecorded_radio.dart';

import 'dev_testing_prefs.dart';
import 'scan_runtime.dart';

/// Active scanner mode and fake-scan scenario.
class ScannerConfig {
  const ScannerConfig({
    required this.mode,
    required this.scenario,
  });

  final ScannerMode mode;
  final FakeDemoScenario scenario;

  ScannerConfig copyWith({
    ScannerMode? mode,
    FakeDemoScenario? scenario,
  }) {
    return ScannerConfig(
      mode: mode ?? this.mode,
      scenario: scenario ?? this.scenario,
    );
  }
}

/// Resolves initial scanner config from compile flags, debug prefs, and device.
Future<ScannerConfig> resolveScannerConfig({
  required Future<bool> Function() isEmulator,
}) async {
  if (const bool.fromEnvironment('UNRECORDED_DEMO_MODE')) {
    return ScannerConfig(
      mode: ScannerMode.demo,
      scenario: fakeDemoScenarioFromEnvironment(),
    );
  }

  if (kReleaseMode) {
    return const ScannerConfig(
      mode: ScannerMode.auto,
      scenario: FakeDemoScenario.random,
    );
  }

  final prefs = await DevTestingPrefs.load();
  final savedMode = prefs.scannerMode;
  final savedScenario = prefs.demoScenario;

  if (savedMode != null) {
    return ScannerConfig(
      mode: savedMode,
      scenario: savedScenario ?? FakeDemoScenario.high,
    );
  }

  if (await isEmulator()) {
    return const ScannerConfig(
      mode: ScannerMode.demo,
      scenario: FakeDemoScenario.high,
    );
  }

  return ScannerConfig(
    mode: ScannerMode.auto,
    scenario: savedScenario ?? FakeDemoScenario.random,
  );
}
