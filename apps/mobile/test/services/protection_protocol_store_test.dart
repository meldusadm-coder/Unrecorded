import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unrecorded_mobile/services/protection_protocol_models.dart';
import 'package:unrecorded_mobile/services/single_engine_protection_protocol_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late SingleEngineProtectionProtocolStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = SingleEngineProtectionProtocolStore(prefs: prefs);
  });

  tearDown(() async {
    await store.dispose();
  });

  group('migration-like sequences', () {
    test('empty prefs migrate to revision 1 Off tuple', () async {
      final result = await store.ensureReady();
      expect(result, isA<ProtocolCommitConfirmed>());
      final tuple = (result as ProtocolCommitConfirmed).tuple;
      expect(tuple.schemaVersion, kProtectionProtocolSchemaVersion);
      expect(tuple.revision, 1);
      expect(tuple.protectionEnabled, isFalse);
      expect(tuple.backgroundModePreferred, isTrue);
      expect(tuple.backgroundRuntimeEnabled, isFalse);
      expect(tuple.explicitlyStopped, isFalse);
      expect(tuple.activeTaskSessionId, isNull);
      expect(tuple.taskPhase, ProtocolTaskPhase.none);
    });

    test('legacy background-on migrates overall intent true', () async {
      await store.dispose();
      SharedPreferences.setMockInitialValues({
        'protection_enabled': false,
        'background_protection_enabled': true,
        'background_protection_explicitly_stopped': false,
      });
      prefs = await SharedPreferences.getInstance();
      store = SingleEngineProtectionProtocolStore(prefs: prefs);

      final result = await store.ensureReady();
      final tuple = (result as ProtocolCommitConfirmed).tuple;
      expect(tuple.protectionEnabled, isTrue);
      expect(tuple.backgroundModePreferred, isTrue);
      expect(tuple.backgroundRuntimeEnabled, isFalse);
      expect(tuple.explicitlyStopped, isFalse);
    });

    test('legacy explicit Stop dominates', () async {
      await store.dispose();
      SharedPreferences.setMockInitialValues({
        'protection_enabled': true,
        'background_protection_enabled': true,
        'background_protection_explicitly_stopped': true,
      });
      prefs = await SharedPreferences.getInstance();
      store = SingleEngineProtectionProtocolStore(prefs: prefs);

      final result = await store.ensureReady();
      final tuple = (result as ProtocolCommitConfirmed).tuple;
      expect(tuple.protectionEnabled, isFalse);
      expect(tuple.backgroundModePreferred, isTrue);
      expect(tuple.explicitlyStopped, isTrue);
    });

    test('beginForegroundIntent then Stop then re-enable', () async {
      await store.ensureReady();
      final enabled = await store.beginForegroundIntent(expectedRevision: 1);
      expect(enabled, isA<ProtocolCommitConfirmed>());
      expect(
        (enabled as ProtocolCommitConfirmed).tuple.protectionEnabled,
        isTrue,
      );
      expect(enabled.tuple.revision, 2);

      final stopped = await store.commitExplicitStop();
      expect(stopped, isA<ProtocolCommitConfirmed>());
      final stoppedTuple = (stopped as ProtocolCommitConfirmed).tuple;
      expect(stoppedTuple.protectionEnabled, isFalse);
      expect(stoppedTuple.explicitlyStopped, isTrue);
      expect(stoppedTuple.revision, 3);

      final state = await store.getState();
      expect(state.stopFenceRaised, isTrue);

      final again = await store.beginForegroundIntent(
        expectedRevision: stoppedTuple.revision,
      );
      expect(again, isA<ProtocolCommitConfirmed>());
      final againTuple = (again as ProtocolCommitConfirmed).tuple;
      expect(againTuple.protectionEnabled, isTrue);
      expect(againTuple.explicitlyStopped, isFalse);
      expect((await store.getState()).stopFenceRaised, isFalse);
    });
  });

  group('Stop fence', () {
    test('failed Stop raises fence and blocks enable/lease', () async {
      await store.dispose();
      store = SingleEngineProtectionProtocolStore(
        prefs: prefs,
        commitFn: (tuple) {
          // Succeed until an explicit Stop tuple is written.
          if (tuple.explicitlyStopped) return false;
          return true;
        },
      );

      final ready = await store.ensureReady();
      expect(ready, isA<ProtocolCommitConfirmed>());
      final enabled = await store.beginForegroundIntent(expectedRevision: 1);
      expect(enabled, isA<ProtocolCommitConfirmed>());

      final stop = await store.commitExplicitStop();
      expect(stop, isA<ProtocolCommitPersistenceUncertain>());
      final state = await store.getState();
      expect(state.stopFenceRaised, isTrue);
      expect(state.persistenceUncertain, isTrue);

      final blocked = await store.beginForegroundIntent(
        expectedRevision: (enabled as ProtocolCommitConfirmed).tuple.revision,
      );
      expect(blocked, isA<ProtocolCommitRejected>());
      expect(
        (blocked as ProtocolCommitRejected).reason,
        ProtocolRejectReason.persistenceUncertain,
      );

      final lease = await store.acquireForegroundLease();
      expect(lease, isA<ScannerLeaseRejected>());
      expect(
        (lease as ScannerLeaseRejected).reason,
        ScannerLeaseRejectReason.persistenceUncertain,
      );
    });

    test('preference change remains allowed under Stop fence', () async {
      await store.ensureReady();
      await store.beginForegroundIntent(expectedRevision: 1);
      final stopped = await store.commitExplicitStop();
      final revision = (stopped as ProtocolCommitConfirmed).tuple.revision;

      final pref = await store.setBackgroundModePreferred(
        expectedRevision: revision,
        preferred: true,
      );
      expect(pref, isA<ProtocolCommitConfirmed>());
      expect(
        (pref as ProtocolCommitConfirmed).tuple.backgroundModePreferred,
        isTrue,
      );
    });
  });

  group('stale revision', () {
    test('setBackgroundModePreferred rejects stale expectedRevision', () async {
      await store.ensureReady();
      final stale = await store.setBackgroundModePreferred(
        expectedRevision: 0,
        preferred: true,
      );
      expect(stale, isA<ProtocolCommitStale>());
      expect((stale as ProtocolCommitStale).current.revision, 1);

      final ok = await store.setBackgroundModePreferred(
        expectedRevision: 1,
        preferred: false,
      );
      expect(ok, isA<ProtocolCommitConfirmed>());
      expect((ok as ProtocolCommitConfirmed).tuple.revision, 2);
      expect(ok.tuple.backgroundModePreferred, isFalse);
    });

    test('beginForegroundIntent rejects stale expectedRevision', () async {
      await store.ensureReady();
      final stale = await store.beginForegroundIntent(expectedRevision: 99);
      expect(stale, isA<ProtocolCommitStale>());
    });
  });

  group('lease reject', () {
    test('second foreground lease is rejected while held', () async {
      await store.ensureReady();
      await store.beginForegroundIntent(expectedRevision: 1);

      final first = await store.acquireForegroundLease();
      expect(first, isA<ScannerLeaseAcquired>());

      final second = await store.acquireForegroundLease();
      expect(second, isA<ScannerLeaseRejected>());
      expect(
        (second as ScannerLeaseRejected).reason,
        ScannerLeaseRejectReason.leaseHeld,
      );

      final leaseId = (first as ScannerLeaseAcquired).lease.leaseId;
      expect(await store.markLeaseActive(leaseId: leaseId), isTrue);
      expect(await store.releaseLease(leaseId: leaseId), isTrue);

      final third = await store.acquireForegroundLease();
      expect(third, isA<ScannerLeaseAcquired>());
    });

    test('Stop fence rejects lease acquire', () async {
      await store.ensureReady();
      await store.beginForegroundIntent(expectedRevision: 1);
      await store.commitExplicitStop();

      final lease = await store.acquireForegroundLease();
      expect(lease, isA<ScannerLeaseRejected>());
      expect(
        (lease as ScannerLeaseRejected).reason,
        ScannerLeaseRejectReason.stopFence,
      );
    });

    test('allocateBackgroundSession is rejected on single-engine store',
        () async {
      await store.ensureReady();
      await store.beginForegroundIntent(expectedRevision: 1);
      final allocate = await store.allocateBackgroundSession(
        expectedRevision: 2,
        attemptId: 'a1',
        processId: 'proc-1',
      );
      expect(allocate, isA<ProtocolCommitRejected>());
      expect(
        (allocate as ProtocolCommitRejected).reason,
        ProtocolRejectReason.guardFailed,
      );
      expect(
        (await store.getState()).tuple?.backgroundRuntimeEnabled,
        isFalse,
      );
    });
  });
}
