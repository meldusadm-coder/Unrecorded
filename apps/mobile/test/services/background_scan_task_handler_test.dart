import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_mobile/features/scan/scan_state.dart';
import 'package:unrecorded_mobile/services/background_protection_snapshot.dart';
import 'package:unrecorded_mobile/services/background_scan_task_handler.dart';
import 'package:unrecorded_mobile/services/fake_protection_protocol_store.dart';
import 'package:unrecorded_mobile/services/protection_protocol_models.dart';
import 'package:unrecorded_mobile/services/scan_runtime.dart';
import 'package:unrecorded_radio/unrecorded_radio.dart';

ProtectionProtocolTuple _allocatedTuple({
  bool protectionEnabled = true,
  bool backgroundRuntimeEnabled = true,
  bool explicitlyStopped = false,
  String? sessionId = 'task-1',
  int? epoch = 3,
  ProtocolTaskPhase taskPhase = ProtocolTaskPhase.allocated,
  int schemaVersion = kProtectionProtocolSchemaVersion,
  int revision = 3,
}) {
  return ProtectionProtocolTuple(
    schemaVersion: schemaVersion,
    revision: revision,
    backgroundModePreferred: true,
    protectionEnabled: protectionEnabled,
    backgroundRuntimeEnabled: backgroundRuntimeEnabled,
    explicitlyStopped: explicitlyStopped,
    activeTaskSessionId: sessionId,
    activeTaskEpoch: epoch,
    activeTaskIncarnationId: null,
    nextTaskGeneration: 2,
    activeStartAttemptId: 'attempt-1',
    activeStartProcessId: 'test-process',
    taskPhase: taskPhase,
    nativeStartUnresolved: true,
  );
}

class _FakeRuntime extends ScanRuntime {
  _FakeRuntime({
    this.preflight = const ScanPreflightResult.ok(),
  });

  ScanPreflightResult preflight;

  @override
  bool get isAndroid => true;

  @override
  Future<ScanPreflightResult> ensureAndroidReady() async => preflight;
}

void main() {
  late List<BackgroundProtectionSnapshot> snapshots;
  late List<String> stopCalls;
  late FakeProtectionProtocolStore store;

  BackgroundScanTaskEngine buildEngine({
    FakeProtectionProtocolStore? protocolStore,
    ScanPreflightResult preflight = const ScanPreflightResult.ok(),
    RadioScanner Function()? scannerFactory,
  }) {
    store = protocolStore ??
        FakeProtectionProtocolStore(
          engineIncarnationId: 'task-engine:1',
          initialTuple: _allocatedTuple(),
        );
    snapshots = [];
    stopCalls = [];
    return BackgroundScanTaskEngine(
      storeFactory: () => store,
      runtime: _FakeRuntime(preflight: preflight),
      scannerFactory: scannerFactory ?? FakeRadioScanner.new,
      onSnapshot: snapshots.add,
      requestStopService: () async {
        stopCalls.add('stop');
      },
    );
  }

  test('fail-closed when explicitly stopped — no ownership snapshot', () async {
    final engine = buildEngine(
      protocolStore: FakeProtectionProtocolStore(
        engineIncarnationId: 'task-engine:1',
        initialTuple: _allocatedTuple(explicitlyStopped: true),
      ),
    );

    await engine.start();

    expect(stopCalls, isNotEmpty);
    expect(engine.isScannerReady, isFalse);
    expect(snapshots, isNotEmpty);
    final last = snapshots.last;
    expect(
      last.stoppedReason,
      BackgroundProtectionStoppedReason.explicitNotificationStop,
    );
    expect(last.isOwnershipCapable, isFalse);
    expect(last.sessionId, isNull);
  });

  test('fail-closed when protection disabled', () async {
    final engine = buildEngine(
      protocolStore: FakeProtectionProtocolStore(
        engineIncarnationId: 'task-engine:1',
        initialTuple: _allocatedTuple(protectionEnabled: false),
      ),
    );

    await engine.start();

    expect(engine.isScannerReady, isFalse);
    expect(stopCalls, isNotEmpty);
    expect(snapshots.last.isOwnershipCapable, isFalse);
  });

  test('fail-closed when background runtime disabled', () async {
    final engine = buildEngine(
      protocolStore: FakeProtectionProtocolStore(
        engineIncarnationId: 'task-engine:1',
        initialTuple: _allocatedTuple(backgroundRuntimeEnabled: false),
      ),
    );

    await engine.start();

    expect(engine.isScannerReady, isFalse);
    expect(snapshots.last.isOwnershipCapable, isFalse);
  });

  test('fail-closed when session is null', () async {
    final engine = buildEngine(
      protocolStore: FakeProtectionProtocolStore(
        engineIncarnationId: 'task-engine:1',
        initialTuple: _allocatedTuple(sessionId: null, epoch: null),
      ),
    );

    await engine.start();

    expect(engine.isScannerReady, isFalse);
    expect(snapshots.last.isOwnershipCapable, isFalse);
    expect(
      snapshots.last.stoppedReason,
      BackgroundProtectionStoppedReason.cancelledBeforeStart,
    );
  });

  test('fail-closed when stop fence raised', () async {
    final seeded = FakeProtectionProtocolStore(
      engineIncarnationId: 'task-engine:1',
      initialTuple: _allocatedTuple(),
    );
    seeded.raiseStopFenceForTest();
    final engine = buildEngine(protocolStore: seeded);

    await engine.start();

    expect(engine.isScannerReady, isFalse);
    expect(snapshots.last.isOwnershipCapable, isFalse);
  });

  test('fail-closed when persistence uncertain', () async {
    final seeded = FakeProtectionProtocolStore(
      engineIncarnationId: 'task-engine:1',
      initialTuple: _allocatedTuple(),
    );
    seeded.markPersistenceUncertainForTest();
    final engine = buildEngine(protocolStore: seeded);

    await engine.start();

    expect(engine.isScannerReady, isFalse);
    expect(
      snapshots.last.stoppedReason,
      BackgroundProtectionStoppedReason.protocolUnavailable,
    );
    expect(snapshots.last.isOwnershipCapable, isFalse);
  });

  test('fail-closed on preflight without constructing ownership', () async {
    final engine = buildEngine(
      preflight: const ScanPreflightResult.fail(
        ScanPreflightFailure.permissionDenied,
      ),
    );

    await engine.start();

    expect(engine.isScannerReady, isFalse);
    expect(snapshots.last.stoppedReason,
        BackgroundProtectionStoppedReason.blocked,);
    expect(
      snapshots.last.taskBlockedCause,
      ScanPreflightFailure.permissionDenied,
    );
    // Session known but lease not claimed yet — not ownership-capable.
    expect(snapshots.last.scannerLeaseId, isNull);
    expect(snapshots.last.isOwnershipCapable, isFalse);
  });

  test('successful start claims lease and emits ownership-capable ready',
      () async {
    final engine = buildEngine();

    await engine.start();

    expect(engine.isScannerReady, isTrue);
    expect(stopCalls, isEmpty);
    final ready = snapshots.where((s) => s.serviceRunning).last;
    expect(ready.isOwnershipCapable, isTrue);
    expect(ready.sessionId, 'task-1');
    expect(ready.sessionEpoch, 3);
    expect(ready.engineIncarnationId, 'task-engine:1');
    expect(ready.scannerLeaseId, isNotNull);
    expect(ready.messageSequence, greaterThan(0));
    expect(ready.scannerPhase, BackgroundScannerPhase.scanning);
    expect(ready.status, ScanStatus.scanning);

    final state = await store.getState();
    expect(state.tuple?.taskPhase, ProtocolTaskPhase.scannerReady);
    expect(state.lease?.phase, ScannerLeasePhase.active);
  });

  test('notification Stop commits protocol concurrently and preserves reason',
      () async {
    final engine = buildEngine();
    await engine.start();
    expect(engine.isScannerReady, isTrue);
    snapshots.clear();
    stopCalls.clear();

    engine.onNotificationStopPressed();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(engine.stopInProgress, isTrue);
    expect(
      engine.terminalReason,
      BackgroundProtectionStoppedReason.explicitNotificationStop,
    );
    expect(stopCalls, isNotEmpty);

    final stopSnap = snapshots.lastWhere(
      (s) =>
          s.stoppedReason ==
          BackgroundProtectionStoppedReason.explicitNotificationStop,
    );
    expect(stopSnap.isOwnershipCapable, isTrue);
    expect(
      stopSnap.stopTransactionOutcome,
      StopTransactionOutcome.confirmed,
    );
    expect(stopSnap.scannerStopOutcome, isNotNull);

    final tuple = (await store.getState()).tuple!;
    expect(tuple.explicitlyStopped, isTrue);
    expect(tuple.protectionEnabled, isFalse);
    expect(tuple.backgroundRuntimeEnabled, isFalse);

    snapshots.clear();
    await engine.destroy(isTimeout: false);
    expect(
      snapshots.last.stoppedReason,
      BackgroundProtectionStoppedReason.explicitNotificationStop,
    );
  });

  test('onDestroy preserves blocked cause', () async {
    final engine = buildEngine(
      preflight: const ScanPreflightResult.fail(
        ScanPreflightFailure.bluetoothOff,
      ),
    );
    await engine.start();
    snapshots.clear();

    await engine.destroy(isTimeout: false);

    expect(
      snapshots.last.stoppedReason,
      BackgroundProtectionStoppedReason.blocked,
    );
    expect(
      snapshots.last.taskBlockedCause,
      ScanPreflightFailure.bluetoothOff,
    );
  });
}
