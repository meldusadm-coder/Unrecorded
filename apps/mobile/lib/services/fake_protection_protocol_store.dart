import 'dart:async';

import 'package:flutter/foundation.dart';

import 'protection_protocol_models.dart';
import 'protection_protocol_store.dart';

/// Deterministic in-memory [ProtectionProtocolStore] for orchestrator tests.
///
/// Supports foreground and background allocation/lease paths without Android.
class FakeProtectionProtocolStore implements ProtectionProtocolStore {
  FakeProtectionProtocolStore({
    String processInstanceId = 'fake-process',
    String engineIncarnationId = 'fake-process:1',
    ProtectionProtocolTuple? initialTuple,
    this.failNextCommit = false,
    this.delay = Duration.zero,
  })  : _processInstanceId = processInstanceId,
        _engineIncarnationId = engineIncarnationId,
        _lastConfirmed = initialTuple;

  final String _processInstanceId;
  final String _engineIncarnationId;

  /// When true, the next persist returns persistenceUncertain then clears.
  bool failNextCommit;
  Duration delay;

  final StreamController<ProtocolChangeNotification> _changes =
      StreamController<ProtocolChangeNotification>.broadcast();

  ProtectionProtocolTuple? _lastConfirmed;
  ScannerLease? _lease;
  var _persistenceUncertain = false;
  var _stopFenceRaised = false;
  final Set<String> _cancelledAttemptIds = {};
  var _leaseSeq = 0;
  var _disposed = false;
  var _ready = false;

  /// Optional hook invoked when a task lease is acquired (tests inject ready).
  void Function(ScannerLease lease)? onTaskLeaseAcquired;

  @override
  Stream<ProtocolChangeNotification> get changes => _changes.stream;

  @override
  Future<ProtectionProtocolState> getState() async {
    await _maybeDelay();
    return ProtectionProtocolState(
      engineIncarnationId: _engineIncarnationId,
      engineKind: ProtocolEngineKind.main,
      processInstanceId: _processInstanceId,
      persistenceUncertain: _persistenceUncertain,
      stopFenceRaised: _stopFenceRaised,
      tuple: _persistenceUncertain ? null : _lastConfirmed,
      lease: _lease,
    );
  }

  @override
  Future<ProtocolCommitResult> ensureReady() async {
    await _maybeDelay();
    if (_persistenceUncertain && _lastConfirmed != null) {
      return ProtocolCommitPersistenceUncertain(
        intendedTuple: _lastConfirmed,
        lastConfirmedTuple: _lastConfirmed,
      );
    }
    if (_lastConfirmed != null) {
      _ready = true;
      return ProtocolCommitConfirmed(_lastConfirmed!);
    }
    final migrated = const ProtectionProtocolTuple(
      schemaVersion: kProtectionProtocolSchemaVersion,
      revision: 1,
      backgroundModePreferred: false,
      protectionEnabled: false,
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
    );
    return _persist(migrated);
  }

  @override
  Future<ProtocolCommitResult> commitExplicitStop() async {
    await _maybeDelay();
    _stopFenceRaised = true;
    final ready = await ensureReady();
    final current = switch (ready) {
      ProtocolCommitConfirmed(:final tuple) => tuple,
      ProtocolCommitPersistenceUncertain(
        :final intendedTuple,
        :final lastConfirmedTuple
      ) =>
        intendedTuple ?? lastConfirmedTuple,
      ProtocolCommitStale(:final current) => current,
      ProtocolCommitRejected(:final current) => current,
    };
    if (current == null) {
      return const ProtocolCommitRejected(
        reason: ProtocolRejectReason.guardFailed,
        current: null,
      );
    }
    final phase = current.activeTaskSessionId != null
        ? ProtocolTaskPhase.cancelling
        : ProtocolTaskPhase.none;
    return _persist(
      current.copyWith(
        revision: current.revision + 1,
        protectionEnabled: false,
        backgroundRuntimeEnabled: false,
        explicitlyStopped: true,
        taskPhase: phase,
      ),
    );
  }

  @override
  Future<ProtocolCommitResult> setBackgroundModePreferred({
    required int expectedRevision,
    required bool preferred,
  }) {
    return _mutate((current) {
      if (current.revision != expectedRevision) {
        return _MutStale(current);
      }
      if (current.backgroundModePreferred == preferred) {
        return _MutOk(current);
      }
      return _MutOk(
        current.copyWith(
          revision: current.revision + 1,
          backgroundModePreferred: preferred,
        ),
      );
    });
  }

  @override
  Future<ProtocolCommitResult> beginForegroundIntent({
    required int expectedRevision,
  }) {
    return _mutate((current) {
      if (_persistenceUncertain) {
        return _MutRejected(ProtocolRejectReason.persistenceUncertain, current);
      }
      if (current.revision != expectedRevision) {
        return _MutStale(current);
      }
      var clearFence = false;
      if (_stopFenceRaised) {
        if (!current.explicitlyStopped) {
          return _MutRejected(ProtocolRejectReason.stopFence, current);
        }
        clearFence = true;
      }
      return _MutOk(
        ProtectionProtocolTuple(
          schemaVersion: current.schemaVersion,
          revision: current.revision + 1,
          backgroundModePreferred: current.backgroundModePreferred,
          protectionEnabled: true,
          backgroundRuntimeEnabled: false,
          explicitlyStopped: false,
          activeTaskSessionId: null,
          activeTaskEpoch: null,
          activeTaskIncarnationId: null,
          nextTaskGeneration: current.nextTaskGeneration,
          activeStartAttemptId: null,
          activeStartProcessId: null,
          taskPhase: ProtocolTaskPhase.none,
          nativeStartUnresolved: false,
        ),
        clearStopFence: clearFence,
      );
    });
  }

  @override
  Future<ProtocolCommitResult> allocateBackgroundSession({
    required int expectedRevision,
    required String attemptId,
    required String processId,
  }) {
    return _mutate((current) {
      if (_persistenceUncertain) {
        return _MutRejected(ProtocolRejectReason.persistenceUncertain, current);
      }
      if (_stopFenceRaised) {
        return _MutRejected(ProtocolRejectReason.stopFence, current);
      }
      if (_cancelledAttemptIds.contains(attemptId)) {
        return _MutRejected(ProtocolRejectReason.attemptFence, current);
      }
      if (current.revision != expectedRevision) {
        return _MutStale(current);
      }
      if (!current.protectionEnabled || current.explicitlyStopped) {
        return _MutRejected(ProtocolRejectReason.guardFailed, current);
      }
      if (current.backgroundRuntimeEnabled ||
          current.activeTaskSessionId != null) {
        return _MutRejected(ProtocolRejectReason.guardFailed, current);
      }
      // Prefer mode must allow background for allocate; tests set preferred.
      final generation = current.nextTaskGeneration;
      final sessionId = 'task-$generation';
      return _MutOk(
        current.copyWith(
          revision: current.revision + 1,
          backgroundRuntimeEnabled: true,
          explicitlyStopped: false,
          activeTaskSessionId: sessionId,
          activeTaskEpoch: current.revision + 1,
          activeTaskIncarnationId: null,
          nextTaskGeneration: generation + 1,
          activeStartAttemptId: attemptId,
          activeStartProcessId: processId,
          taskPhase: ProtocolTaskPhase.allocated,
          nativeStartUnresolved: true,
        ),
      );
    });
  }

  @override
  Future<ProtocolCommitResult> cancelBackgroundAttempt({
    required String attemptId,
  }) {
    _cancelledAttemptIds.add(attemptId);
    return _mutate((current) {
      if (current.activeStartAttemptId != attemptId) {
        return _MutOk(current);
      }
      return _MutOk(
        current.copyWith(
          revision: current.revision + 1,
          backgroundRuntimeEnabled: false,
          taskPhase: ProtocolTaskPhase.cancelling,
        ),
      );
    });
  }

  @override
  Future<ProtocolCommitResult> switchToForegroundIntent({
    required int expectedRevision,
  }) {
    return _mutate((current) {
      if (current.revision != expectedRevision) {
        return _MutStale(current);
      }
      if (!current.protectionEnabled || current.explicitlyStopped) {
        return _MutRejected(ProtocolRejectReason.guardFailed, current);
      }
      return _MutOk(
        current.copyWith(
          revision: current.revision + 1,
          backgroundModePreferred: false,
          backgroundRuntimeEnabled: false,
          taskPhase: current.activeTaskSessionId != null
              ? ProtocolTaskPhase.cancelling
              : ProtocolTaskPhase.none,
        ),
      );
    });
  }

  @override
  Future<ProtocolCommitResult> claimTaskIncarnation({
    required int expectedRevision,
    required String sessionId,
    required String incarnationId,
  }) {
    return _mutate((current) {
      if (current.revision != expectedRevision) {
        return _MutStale(current);
      }
      if (current.activeTaskSessionId != sessionId ||
          !current.backgroundRuntimeEnabled) {
        return _MutRejected(ProtocolRejectReason.guardFailed, current);
      }
      return _MutOk(
        current.copyWith(
          revision: current.revision + 1,
          activeTaskIncarnationId: incarnationId,
        ),
      );
    });
  }

  @override
  Future<ProtocolCommitResult> markTaskScannerReady({
    required int expectedRevision,
    required String sessionId,
    required int epoch,
    required String incarnationId,
    required String leaseId,
  }) {
    return _mutate((current) {
      if (current.revision != expectedRevision) {
        return _MutStale(current);
      }
      if (current.activeTaskSessionId != sessionId ||
          current.activeTaskEpoch != epoch ||
          current.activeTaskIncarnationId != incarnationId) {
        return _MutRejected(ProtocolRejectReason.guardFailed, current);
      }
      if (_lease == null || _lease!.leaseId != leaseId) {
        return _MutRejected(ProtocolRejectReason.guardFailed, current);
      }
      return _MutOk(
        current.copyWith(
          revision: current.revision + 1,
          taskPhase: ProtocolTaskPhase.scannerReady,
        ),
      );
    });
  }

  @override
  Future<ProtocolCommitResult> markNativeStartResolved({
    required int expectedRevision,
    required String attemptId,
  }) {
    return _mutate((current) {
      if (current.revision != expectedRevision) {
        return _MutStale(current);
      }
      if (current.activeStartAttemptId != attemptId) {
        return _MutRejected(ProtocolRejectReason.guardFailed, current);
      }
      return _MutOk(
        current.copyWith(
          revision: current.revision + 1,
          nativeStartUnresolved: false,
        ),
      );
    });
  }

  @override
  Future<ProtocolCommitResult> finaliseSession({
    required int expectedRevision,
    required String sessionId,
  }) {
    return _mutate((current) {
      if (current.revision != expectedRevision) {
        return _MutStale(current);
      }
      if (current.activeTaskSessionId != sessionId) {
        return _MutRejected(ProtocolRejectReason.guardFailed, current);
      }
      if (current.nativeStartUnresolved) {
        return _MutRejected(ProtocolRejectReason.guardFailed, current);
      }
      return _MutOk(
        ProtectionProtocolTuple(
          schemaVersion: current.schemaVersion,
          revision: current.revision + 1,
          backgroundModePreferred: current.backgroundModePreferred,
          protectionEnabled: current.protectionEnabled,
          backgroundRuntimeEnabled: false,
          explicitlyStopped: current.explicitlyStopped,
          activeTaskSessionId: null,
          activeTaskEpoch: null,
          activeTaskIncarnationId: null,
          nextTaskGeneration: current.nextTaskGeneration,
          activeStartAttemptId: null,
          activeStartProcessId: null,
          taskPhase: ProtocolTaskPhase.none,
          nativeStartUnresolved: false,
        ),
      );
    });
  }

  @override
  Future<ProtocolCommitResult> reapDeadProcessStartLatch({
    required int expectedRevision,
    required String processId,
  }) {
    return _mutate((current) {
      if (current.revision != expectedRevision) {
        return _MutStale(current);
      }
      if (current.activeStartProcessId != processId) {
        return _MutRejected(ProtocolRejectReason.guardFailed, current);
      }
      return _MutOk(
        current.copyWith(
          revision: current.revision + 1,
          nativeStartUnresolved: false,
        ),
      );
    });
  }

  @override
  Future<ScannerLeaseAcquireResult> acquireForegroundLease({
    String? rollbackForAttemptId,
  }) async {
    await _maybeDelay();
    if (_persistenceUncertain) {
      return const ScannerLeaseRejected(
        ScannerLeaseRejectReason.persistenceUncertain,
      );
    }
    if (_stopFenceRaised) {
      return const ScannerLeaseRejected(ScannerLeaseRejectReason.stopFence);
    }
    if (_lease != null) {
      return const ScannerLeaseRejected(ScannerLeaseRejectReason.leaseHeld);
    }
    final tuple = _lastConfirmed;
    final guardOk = tuple != null &&
        tuple.protectionEnabled &&
        !tuple.explicitlyStopped &&
        !tuple.backgroundRuntimeEnabled &&
        (rollbackForAttemptId == null ||
            tuple.activeStartAttemptId == rollbackForAttemptId);
    if (!guardOk) {
      return const ScannerLeaseRejected(ScannerLeaseRejectReason.guardFailed);
    }
    _leaseSeq += 1;
    final lease = ScannerLease(
      ownerKind: ScannerLeaseOwnerKind.foreground,
      leaseId: 'fg-lease-$_leaseSeq',
      engineIncarnationId: _engineIncarnationId,
      taskSessionId: null,
      taskEpoch: null,
      phase: ScannerLeasePhase.starting,
    );
    _lease = lease;
    return ScannerLeaseAcquired(lease);
  }

  @override
  Future<ScannerLeaseAcquireResult> acquireTaskLease({
    required String sessionId,
    required int epoch,
    String? incarnationId,
  }) async {
    await _maybeDelay();
    if (_persistenceUncertain) {
      return const ScannerLeaseRejected(
        ScannerLeaseRejectReason.persistenceUncertain,
      );
    }
    if (_stopFenceRaised) {
      return const ScannerLeaseRejected(ScannerLeaseRejectReason.stopFence);
    }
    if (_lease != null) {
      return const ScannerLeaseRejected(ScannerLeaseRejectReason.leaseHeld);
    }
    final tuple = _lastConfirmed;
    if (tuple == null ||
        !tuple.backgroundRuntimeEnabled ||
        tuple.activeTaskSessionId != sessionId ||
        tuple.activeTaskEpoch != epoch) {
      return const ScannerLeaseRejected(ScannerLeaseRejectReason.guardFailed);
    }
    final incarnation = incarnationId ?? _engineIncarnationId;
    _leaseSeq += 1;
    final lease = ScannerLease(
      ownerKind: ScannerLeaseOwnerKind.background,
      leaseId: 'bg-lease-$_leaseSeq',
      engineIncarnationId: incarnation,
      taskSessionId: sessionId,
      taskEpoch: epoch,
      phase: ScannerLeasePhase.starting,
    );
    _lease = lease;
    onTaskLeaseAcquired?.call(lease);
    return ScannerLeaseAcquired(lease);
  }

  @override
  Future<bool> markLeaseActive({required String leaseId}) async {
    await _maybeDelay();
    final existing = _lease;
    if (existing == null || existing.leaseId != leaseId) return false;
    _lease = existing.copyWith(phase: ScannerLeasePhase.active);
    return true;
  }

  @override
  Future<bool> releaseLease({required String leaseId}) async {
    await _maybeDelay();
    final existing = _lease;
    if (existing == null || existing.leaseId != leaseId) return false;
    _lease = null;
    return true;
  }

  @override
  Future<bool> releaseLeaseForEngine() async {
    await _maybeDelay();
    if (_lease == null) return false;
    _lease = null;
    return true;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _changes.close();
  }

  /// Simulates a task-engine ready commit after service start (test helper).
  Future<ProtocolCommitResult> simulateTaskReady({
    required String sessionId,
    required int epoch,
    required String incarnationId,
    required String leaseId,
  }) async {
    final state = await getState();
    final revision = state.tuple?.revision;
    if (revision == null) {
      return const ProtocolCommitRejected(
        reason: ProtocolRejectReason.guardFailed,
        current: null,
      );
    }
    await claimTaskIncarnation(
      expectedRevision: revision,
      sessionId: sessionId,
      incarnationId: incarnationId,
    );
    final afterClaim = (await getState()).tuple!;
    await markLeaseActive(leaseId: leaseId);
    return markTaskScannerReady(
      expectedRevision: afterClaim.revision,
      sessionId: sessionId,
      epoch: epoch,
      incarnationId: incarnationId,
      leaseId: leaseId,
    );
  }

  Future<void> _maybeDelay() async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
  }

  Future<ProtocolCommitResult> _mutate(
    _Mut Function(ProtectionProtocolTuple current) block,
  ) async {
    await _maybeDelay();
    final ready = await ensureReady();
    if (ready is ProtocolCommitPersistenceUncertain) {
      return ProtocolCommitRejected(
        reason: ProtocolRejectReason.persistenceUncertain,
        current: ready.lastConfirmedTuple,
      );
    }
    final current = _lastConfirmed;
    if (current == null) {
      return const ProtocolCommitRejected(
        reason: ProtocolRejectReason.guardFailed,
        current: null,
      );
    }
    final outcome = block(current);
    switch (outcome) {
      case _MutOk(:final tuple, :final clearStopFence):
        if (tuple.revision == current.revision) {
          return ProtocolCommitConfirmed(current);
        }
        final persisted = await _persist(tuple);
        if (persisted is ProtocolCommitConfirmed && clearStopFence) {
          _stopFenceRaised = false;
        }
        return persisted;
      case _MutStale(:final current):
        return ProtocolCommitStale(current);
      case _MutRejected(:final reason, :final current):
        return ProtocolCommitRejected(reason: reason, current: current);
    }
  }

  Future<ProtocolCommitResult> _persist(
    ProtectionProtocolTuple intended,
  ) async {
    if (failNextCommit) {
      failNextCommit = false;
      _persistenceUncertain = true;
      return ProtocolCommitPersistenceUncertain(
        intendedTuple: intended,
        lastConfirmedTuple: _lastConfirmed,
      );
    }
    _lastConfirmed = intended;
    _persistenceUncertain = false;
    _ready = true;
    if (!_changes.isClosed) {
      _changes.add(
        ProtocolChangeNotification(
          revision: intended.revision,
          engineIncarnationId: _engineIncarnationId,
        ),
      );
    }
    return ProtocolCommitConfirmed(intended);
  }

  @visibleForTesting
  bool get isReady => _ready;

  /// Test-only: force persistence-uncertain so getState returns a null tuple.
  @visibleForTesting
  void markPersistenceUncertainForTest() {
    _persistenceUncertain = true;
  }

  /// Test-only: raise the process Stop fence without committing Stop.
  @visibleForTesting
  void raiseStopFenceForTest() {
    _stopFenceRaised = true;
  }
}

sealed class _Mut {
  const _Mut();
}

final class _MutOk extends _Mut {
  const _MutOk(this.tuple, {this.clearStopFence = false});
  final ProtectionProtocolTuple tuple;
  final bool clearStopFence;
}

final class _MutStale extends _Mut {
  const _MutStale(this.current);
  final ProtectionProtocolTuple current;
}

final class _MutRejected extends _Mut {
  const _MutRejected(this.reason, this.current);
  final ProtocolRejectReason reason;
  final ProtectionProtocolTuple? current;
}
