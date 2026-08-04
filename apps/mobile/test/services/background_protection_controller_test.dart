import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unrecorded_mobile/services/background_protection_snapshot.dart';
import 'package:unrecorded_mobile/services/background_protection_state.dart';
import 'package:unrecorded_mobile/services/protection_orchestrator_providers.dart';
import 'package:unrecorded_mobile/services/protection_protocol_models.dart';
import 'package:unrecorded_mobile/services/protection_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('orchestrator state maps to background UI shim fields', () {
    const orch = ProtectionOrchestratorState(
      confirmedOwner: ScannerOwner.background,
      backgroundMechanics: BackgroundServiceMechanics.ready,
    );
    final mapped = backgroundProtectionStateFromOrchestrator(orch);
    expect(mapped.serviceRunning, isTrue);
    expect(mapped.ownsScanning, isTrue);
  });

  test('android-stopped issue maps to stopped banner reason', () {
    const orch = ProtectionOrchestratorState(
      issue: BackgroundProtectionIssue.androidStoppedBackgroundProtection,
      lastConfirmedTuple: ProtectionProtocolTuple(
        schemaVersion: 1,
        revision: 1,
        backgroundModePreferred: true,
        protectionEnabled: true,
        backgroundRuntimeEnabled: false,
        explicitlyStopped: false,
        activeTaskSessionId: null,
        activeTaskEpoch: null,
        activeTaskIncarnationId: null,
        nextTaskGeneration: 1,
        activeStartAttemptId: null,
        activeStartProcessId: null,
        taskPhase: ProtocolTaskPhase.none,
        nativeStartUnresolved: false,
      ),
    );
    final mapped = backgroundProtectionStateFromOrchestrator(orch);
    expect(mapped.showsStoppedByAndroidBanner, isTrue);
  });
}
