import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_mobile/features/scan/scan_state.dart';
import 'package:unrecorded_mobile/services/background_protection_preflight.dart';
import 'package:unrecorded_mobile/services/background_protection_snapshot.dart';
import 'package:unrecorded_mobile/services/protection_orchestrator.dart';
import 'package:unrecorded_mobile/services/protection_protocol_models.dart';
import 'package:unrecorded_mobile/services/protection_state.dart';
import 'package:unrecorded_mobile/services/risk_notification_service.dart';
import 'package:unrecorded_mobile/services/scan_runtime.dart';
import 'package:unrecorded_mobile/services/fake_protection_protocol_store.dart';

import '../support/fake_foreground_service_controller.dart';

class _OkPreflight extends BackgroundProtectionPreflight {
  _OkPreflight()
      : super(
          runtime: const ScanRuntime(),
          notifications: RiskNotificationService(
            RiskNotificationService.sharedPlugin,
          ),
        );

  @override
  Future<BackgroundProtectionPreflightResult> check({
    bool requestPermissions = true,
  }) async {
    return const BackgroundProtectionPreflightResult.ok();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeProtectionProtocolStore store;
  late FakeForegroundServiceController fgs;
  late BackgroundOwnershipClaim claim;
  late List<ScannerOwner> owners;
  late ProtectionOrchestrator orch;

  Future<ForegroundStartResult> Function({required ScannerLease lease})
      startFg = ({required lease}) async => const ForegroundStarted();
  Future<ForegroundPauseResult> Function() pauseFg =
      () async => const ForegroundPaused();

  ProtectionOrchestrator build({
    bool supportBackground = true,
    Duration? readinessTimeout,
    Duration? stopTimeout,
  }) {
    store = FakeProtectionProtocolStore();
    fgs = FakeForegroundServiceController();
    claim = BackgroundOwnershipClaim();
    owners = [];
    orch = ProtectionOrchestrator(
      protocolStore: store,
      backgroundClaim: claim,
      startForeground: ({required lease}) => startFg(lease: lease),
      pauseForeground: () => pauseFg(),
      foregroundService: fgs,
      backgroundPreflight: _OkPreflight(),
      applyMirroredScanState: (_) {},
      onOwnerChanged: owners.add,
      supportBackground: supportBackground,
      readinessTimeout: readinessTimeout ?? const Duration(seconds: 2),
      stopTimeout: stopTimeout ?? const Duration(seconds: 20),
      processId: 'test-process',
    );
    return orch;
  }

  tearDown(() {
    try {
      orch.dispose();
    } catch (_) {}
  });

  test('busy is evaluated before noOp for equal mode preference', () async {
    build(supportBackground: false);
    // Admit an enable so the orchestrator is busy.
    final delayed = Completer<ForegroundStartResult>();
    startFg = ({required lease}) => delayed.future;

    final enableFuture = orch.turnProtectionOn();
    // While enable is in flight, equal preferred mode must return busy.
    final busy = await orch.setBackgroundModePreferred(false);
    expect(busy, isA<ProtectionBusy>());

    delayed.complete(const ForegroundStarted());
    await enableFuture;
  });

  test('stop supersedes an in-flight enable', () async {
    build(supportBackground: false);
    final gate = Completer<ForegroundStartResult>();
    startFg = ({required lease}) => gate.future;

    final enableFuture = orch.turnProtectionOn();
    final stopFuture = orch.stopAllProtection();

    final enableOutcome = await enableFuture;
    expect(enableOutcome, isA<ProtectionSuperseded>());

    gate.complete(const ForegroundStarted());
    final stopOutcome = await stopFuture;
    expect(stopOutcome, isA<ProtectionCompleted>());
    expect(orch.state.confirmedOwner, ScannerOwner.none);
  });

  test('late foreground success after Stop is cleaned without ownership',
      () async {
    build(supportBackground: false);
    var pauseCount = 0;
    final startEntered = Completer<void>();
    final gate = Completer<ForegroundStartResult>();
    startFg = ({required lease}) async {
      if (!startEntered.isCompleted) startEntered.complete();
      return gate.future;
    };
    pauseFg = () async {
      pauseCount++;
      return const ForegroundPaused();
    };

    final enableFuture = orch.turnProtectionOn();
    await startEntered.future;
    final stopFuture = orch.stopAllProtection();
    await enableFuture;
    await stopFuture;

    gate.complete(const ForegroundStarted());
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(orch.state.confirmedOwner, ScannerOwner.none);
    expect(pauseCount, greaterThan(0));
  });

  test('Off to foreground happy path', () async {
    build(supportBackground: false);
    final outcome = await orch.turnProtectionOn();
    expect(outcome, isA<ProtectionCompleted>());
    expect(orch.state.confirmedOwner, ScannerOwner.foreground);
    expect(orch.state.lastConfirmedTuple?.protectionEnabled, isTrue);
    expect(orch.state.lastConfirmedTuple?.explicitlyStopped, isFalse);
    expect(owners, contains(ScannerOwner.foreground));
  });

  test('Off to background happy path with fake service ready snapshot',
      () async {
    build(supportBackground: true);

    await orch.setBackgroundModePreferred(true);

    // When service starts, simulate task ready snapshot.
    fgs = FakeForegroundServiceController();
    // Rebuild with hook that emits ready after start.
    orch.dispose();
    store = FakeProtectionProtocolStore();
    claim = BackgroundOwnershipClaim();
    owners = [];
    final localFgs = FakeForegroundServiceController();
    orch = ProtectionOrchestrator(
      protocolStore: store,
      backgroundClaim: claim,
      startForeground: ({required lease}) async => const ForegroundStarted(),
      pauseForeground: () async => const ForegroundPaused(),
      foregroundService: localFgs,
      backgroundPreflight: _OkPreflight(),
      applyMirroredScanState: (_) {},
      onOwnerChanged: owners.add,
      supportBackground: true,
      readinessTimeout: const Duration(seconds: 3),
      processId: 'test-process',
    );

    await orch.setBackgroundModePreferred(true);

    // Emit ready shortly after enable begins (after allocate+start).
    scheduleMicrotask(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final tuple = (await store.getState()).tuple;
      if (tuple?.activeTaskSessionId == null) return;
      final leaseResult = await store.acquireTaskLease(
        sessionId: tuple!.activeTaskSessionId!,
        epoch: tuple.activeTaskEpoch!,
        incarnationId: 'task-inc-1',
      );
      if (leaseResult is! ScannerLeaseAcquired) return;
      final lease = leaseResult.lease;
      await store.simulateTaskReady(
        sessionId: tuple.activeTaskSessionId!,
        epoch: tuple.activeTaskEpoch!,
        incarnationId: 'task-inc-1',
        leaseId: lease.leaseId,
      );
      localFgs.emitTaskData(
        BackgroundProtectionSnapshot(
          status: ScanStatus.scanning,
          riskLevel: RiskLevel.low,
          score: 0,
          reasonLabels: const [],
          possibleRiskCount: 0,
          otherNearbyCount: 0,
          isDemoMode: false,
          serviceRunning: true,
          sessionId: tuple.activeTaskSessionId,
          sessionEpoch: tuple.activeTaskEpoch,
          engineIncarnationId: 'task-inc-1',
          scannerLeaseId: lease.leaseId,
          messageSequence: 1,
          scannerPhase: BackgroundScannerPhase.scanning,
        ).toJson(),
      );
    });

    final outcome = await orch.turnProtectionOn();
    expect(outcome, isA<ProtectionCompleted>());
    expect(orch.state.confirmedOwner, ScannerOwner.background);
    expect(claim.isHeld, isTrue);
  });

  test('stop finalisation publishes stable Off', () async {
    build(supportBackground: false);
    await orch.turnProtectionOn();
    expect(orch.state.confirmedOwner, ScannerOwner.foreground);

    final stop = await orch.stopAllProtection();
    expect(stop, isA<ProtectionCompleted>());
    expect(orch.state.confirmedOwner, ScannerOwner.none);
    expect(orch.state.lastConfirmedTuple?.explicitlyStopped, isTrue);
    expect(orch.state.lastConfirmedTuple?.protectionEnabled, isFalse);
    expect(orch.state.isStableOff || !orch.state.isBusy, isTrue);
  });

  test('stop times out to recovery instead of hanging busy', () async {
    var hangPause = false;
    pauseFg = () async {
      if (hangPause) return Completer<ForegroundPauseResult>().future;
      return const ForegroundPaused();
    };
    build(
      supportBackground: false,
      stopTimeout: const Duration(milliseconds: 40),
    );
    await orch.turnProtectionOn();
    hangPause = true;

    final stop = await orch.stopAllProtection();
    expect(stop, isA<ProtectionFailed>());
    expect(orch.state.transition, ProtectionTransitionPhase.idle);
    expect(orch.state.activeOperationId, isNull);
    expect(orch.state.issue, BackgroundProtectionIssue.serviceStopFailed);
  });

  test('turning background off while protecting switches to foreground',
      () async {
    build(supportBackground: true);
    // Force background ready path via fake ready snapshot.
    orch.dispose();
    store = FakeProtectionProtocolStore();
    claim = BackgroundOwnershipClaim();
    owners = [];
    final localFgs = FakeForegroundServiceController();
    orch = ProtectionOrchestrator(
      protocolStore: store,
      backgroundClaim: claim,
      startForeground: ({required lease}) async => const ForegroundStarted(),
      pauseForeground: () async => const ForegroundPaused(),
      foregroundService: localFgs,
      backgroundPreflight: _OkPreflight(),
      applyMirroredScanState: (_) {},
      onOwnerChanged: owners.add,
      supportBackground: true,
      readinessTimeout: const Duration(seconds: 3),
      processId: 'test-process',
    );

    scheduleMicrotask(() async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      final tuple = (await store.getState()).tuple;
      if (tuple?.activeTaskSessionId == null) return;
      final leaseResult = await store.acquireTaskLease(
        sessionId: tuple!.activeTaskSessionId!,
        epoch: tuple.activeTaskEpoch!,
        incarnationId: 'task-inc-switch',
      );
      if (leaseResult is! ScannerLeaseAcquired) return;
      await store.simulateTaskReady(
        sessionId: tuple.activeTaskSessionId!,
        epoch: tuple.activeTaskEpoch!,
        incarnationId: 'task-inc-switch',
        leaseId: leaseResult.lease.leaseId,
      );
      localFgs.emitTaskData(
        BackgroundProtectionSnapshot(
          status: ScanStatus.scanning,
          riskLevel: RiskLevel.low,
          score: 0,
          reasonLabels: const [],
          possibleRiskCount: 0,
          otherNearbyCount: 0,
          isDemoMode: false,
          serviceRunning: true,
          sessionId: tuple.activeTaskSessionId,
          sessionEpoch: tuple.activeTaskEpoch,
          engineIncarnationId: 'task-inc-switch',
          scannerLeaseId: leaseResult.lease.leaseId,
          messageSequence: 1,
          scannerPhase: BackgroundScannerPhase.scanning,
        ).toJson(),
      );
    });

    final on = await orch.turnProtectionOn();
    expect(on, isA<ProtectionCompleted>());
    expect(orch.state.confirmedOwner, ScannerOwner.background);

    final switched = await orch.setBackgroundModePreferred(false);
    expect(
      switched,
      isA<ProtectionCompleted>(),
      reason: 'issue=${orch.state.issue}',
    );
    expect(orch.state.lastConfirmedTuple?.backgroundModePreferred, isFalse);
    expect(orch.state.confirmedOwner, ScannerOwner.foreground);
  });

  test('stop while background-owned always pauses foreground scan UI',
      () async {
    var pauseCalls = 0;
    pauseFg = () async {
      pauseCalls++;
      return const ForegroundPaused();
    };
    build(supportBackground: true);
    orch.dispose();
    store = FakeProtectionProtocolStore();
    claim = BackgroundOwnershipClaim();
    owners = [];
    final localFgs = FakeForegroundServiceController();
    orch = ProtectionOrchestrator(
      protocolStore: store,
      backgroundClaim: claim,
      startForeground: ({required lease}) async => const ForegroundStarted(),
      pauseForeground: () => pauseFg(),
      foregroundService: localFgs,
      backgroundPreflight: _OkPreflight(),
      applyMirroredScanState: (_) {},
      onOwnerChanged: owners.add,
      supportBackground: true,
      readinessTimeout: const Duration(seconds: 3),
      processId: 'test-process',
    );

    scheduleMicrotask(() async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      final tuple = (await store.getState()).tuple;
      if (tuple?.activeTaskSessionId == null) return;
      final leaseResult = await store.acquireTaskLease(
        sessionId: tuple!.activeTaskSessionId!,
        epoch: tuple.activeTaskEpoch!,
        incarnationId: 'task-inc-stop',
      );
      if (leaseResult is! ScannerLeaseAcquired) return;
      await store.simulateTaskReady(
        sessionId: tuple.activeTaskSessionId!,
        epoch: tuple.activeTaskEpoch!,
        incarnationId: 'task-inc-stop',
        leaseId: leaseResult.lease.leaseId,
      );
      localFgs.emitTaskData(
        BackgroundProtectionSnapshot(
          status: ScanStatus.scanning,
          riskLevel: RiskLevel.low,
          score: 0,
          reasonLabels: const [],
          possibleRiskCount: 0,
          otherNearbyCount: 0,
          isDemoMode: false,
          serviceRunning: true,
          sessionId: tuple.activeTaskSessionId,
          sessionEpoch: tuple.activeTaskEpoch,
          engineIncarnationId: 'task-inc-stop',
          scannerLeaseId: leaseResult.lease.leaseId,
          messageSequence: 1,
          scannerPhase: BackgroundScannerPhase.scanning,
        ).toJson(),
      );
    });

    final on = await orch.turnProtectionOn();
    expect(on, isA<ProtectionCompleted>());
    expect(orch.state.confirmedOwner, ScannerOwner.background);

    final stop = await orch.stopAllProtection();
    expect(stop, isA<ProtectionCompleted>());
    expect(pauseCalls, greaterThan(0));
    expect(orch.state.confirmedOwner, ScannerOwner.none);
  });

  test('disposal completes pending Futures with disposed', () async {
    build(supportBackground: false);
    final gate = Completer<ForegroundStartResult>();
    startFg = ({required lease}) => gate.future;

    final enableFuture = orch.turnProtectionOn();
    orch.dispose();

    final outcome = await enableFuture;
    expect(outcome, isA<ProtectionDisposed>());
    gate.complete(const ForegroundStarted());
  });
}
