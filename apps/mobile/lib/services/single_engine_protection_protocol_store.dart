import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'protection_protocol_models.dart';
import 'protection_protocol_store.dart';

/// Non-Android / single-engine adapter.
///
/// Persists foreground intent through SharedPreferences, keeps one in-memory
/// lease, and leaves background/session fields inactive. Does not claim
/// cross-engine Android semantics.
class SingleEngineProtectionProtocolStore implements ProtectionProtocolStore {
  SingleEngineProtectionProtocolStore({
    required SharedPreferences prefs,
    String? processInstanceId,
    String? engineIncarnationId,
    @visibleForTesting bool Function(ProtectionProtocolTuple tuple)? commitFn,
  })  : _prefs = prefs,
        _processInstanceId = processInstanceId ?? 'single-engine',
        _engineIncarnationId =
            engineIncarnationId ?? '${processInstanceId ?? 'single-engine'}:1',
        _commitFn = commitFn;

  static const _keySchemaVersion = 'protection_protocol_schema_version';
  static const _keyRevision = 'protection_protocol_revision';
  static const _keyBackgroundModePreferred = 'background_mode_preferred';
  static const _keyProtectionEnabled = 'protection_enabled';
  static const _keyExplicitlyStopped = 'explicitly_stopped';
  static const _keyLegacyBackgroundProtectionEnabled =
      'background_protection_enabled';
  static const _keyLegacyExplicitlyStopped =
      'background_protection_explicitly_stopped';

  final SharedPreferences _prefs;
  final String _processInstanceId;
  final String _engineIncarnationId;
  final bool Function(ProtectionProtocolTuple tuple)? _commitFn;

  final StreamController<ProtocolChangeNotification> _changes =
      StreamController<ProtocolChangeNotification>.broadcast();

  ProtectionProtocolTuple? _lastConfirmed;
  ProtectionProtocolTuple? _privateAuthority;
  LegacyProtectionSnapshot? _capturedLegacy;
  ScannerLease? _lease;
  var _persistenceUncertain = false;
  var _stopFenceRaised = false;
  var _leaseSeq = 0;
  var _disposed = false;

  @override
  Stream<ProtocolChangeNotification> get changes => _changes.stream;

  @override
  Future<ProtectionProtocolState> getState() async {
    final tuple = _persistenceUncertain ? null : _lastConfirmed;
    return ProtectionProtocolState(
      engineIncarnationId: _engineIncarnationId,
      engineKind: ProtocolEngineKind.main,
      processInstanceId: _processInstanceId,
      persistenceUncertain: _persistenceUncertain,
      stopFenceRaised: _stopFenceRaised,
      tuple: tuple,
      lease: _lease,
    );
  }

  @override
  Future<ProtocolCommitResult> ensureReady() async {
    return _ensureReady();
  }

  @override
  Future<ProtocolCommitResult> commitExplicitStop() async {
    _stopFenceRaised = true;
    final ready = await _ensureReady();
    final current = switch (ready) {
          ProtocolCommitConfirmed(:final tuple) => tuple,
          ProtocolCommitPersistenceUncertain(
            :final intendedTuple,
            :final lastConfirmedTuple
          ) =>
            intendedTuple ?? lastConfirmedTuple,
          ProtocolCommitStale(:final current) => current,
          ProtocolCommitRejected(:final current) => current,
        } ??
        _privateAuthority ??
        _lastConfirmed;

    if (current == null) {
      return const ProtocolCommitRejected(
        reason: ProtocolRejectReason.guardFailed,
        current: null,
      );
    }

    final intended = _commitExplicitStop(current);
    return _persist(intended);
  }

  @override
  Future<ProtocolCommitResult> setBackgroundModePreferred({
    required int expectedRevision,
    required bool preferred,
  }) {
    return _mutate((current) {
      return _setBackgroundModePreferred(
        current: current,
        expectedRevision: expectedRevision,
        preferred: preferred,
      );
    });
  }

  @override
  Future<ProtocolCommitResult> beginForegroundIntent({
    required int expectedRevision,
  }) {
    return _mutate((current) {
      return _beginForegroundIntent(
        current: current,
        expectedRevision: expectedRevision,
      );
    });
  }

  @override
  Future<ProtocolCommitResult> allocateBackgroundSession({
    required int expectedRevision,
    required String attemptId,
    required String processId,
  }) async {
    // Background runtime is inactive on the single-engine adapter.
    final ready = await _ensureReady();
    if (ready is ProtocolCommitPersistenceUncertain) {
      return ProtocolCommitRejected(
        reason: ProtocolRejectReason.persistenceUncertain,
        current: ready.lastConfirmedTuple,
      );
    }
    final current = _lastConfirmed;
    return ProtocolCommitRejected(
      reason: ProtocolRejectReason.guardFailed,
      current: current,
    );
  }

  @override
  Future<ProtocolCommitResult> cancelBackgroundAttempt({
    required String attemptId,
  }) async {
    final ready = await _ensureReady();
    if (ready is! ProtocolCommitConfirmed) {
      return ready is ProtocolCommitPersistenceUncertain
          ? ProtocolCommitRejected(
              reason: ProtocolRejectReason.persistenceUncertain,
              current: ready.lastConfirmedTuple,
            )
          : ready;
    }
    // No active background attempt — fence-only no-op acceptance.
    return ProtocolCommitConfirmed(ready.tuple);
  }

  @override
  Future<ProtocolCommitResult> switchToForegroundIntent({
    required int expectedRevision,
  }) {
    return _mutate((current) {
      final uncertain = _rejectIfUncertain(current);
      if (uncertain != null) return uncertain;
      final stale = _requireRevision(current, expectedRevision);
      if (stale != null) return stale;
      if (_stopFenceRaised && !current.explicitlyStopped) {
        return _MutationRejected(ProtocolRejectReason.stopFence, current);
      }
      if (!current.protectionEnabled || current.explicitlyStopped) {
        return _MutationRejected(ProtocolRejectReason.guardFailed, current);
      }
      return _MutationAccepted(
        _clearedSessionTuple(
          schemaVersion: current.schemaVersion,
          revision: current.revision + 1,
          backgroundModePreferred: false,
          protectionEnabled: true,
          explicitlyStopped: false,
          nextTaskGeneration: current.nextTaskGeneration,
        ),
      );
    });
  }

  @override
  Future<ProtocolCommitResult> claimTaskIncarnation({
    required int expectedRevision,
    required String sessionId,
    required String incarnationId,
  }) async {
    final current = (await _ensureReadyConfirmed())?.tuple;
    return ProtocolCommitRejected(
      reason: ProtocolRejectReason.guardFailed,
      current: current,
    );
  }

  @override
  Future<ProtocolCommitResult> markTaskScannerReady({
    required int expectedRevision,
    required String sessionId,
    required int epoch,
    required String incarnationId,
    required String leaseId,
  }) async {
    final current = (await _ensureReadyConfirmed())?.tuple;
    return ProtocolCommitRejected(
      reason: ProtocolRejectReason.guardFailed,
      current: current,
    );
  }

  @override
  Future<ProtocolCommitResult> markNativeStartResolved({
    required int expectedRevision,
    required String attemptId,
  }) async {
    final current = (await _ensureReadyConfirmed())?.tuple;
    return ProtocolCommitRejected(
      reason: ProtocolRejectReason.guardFailed,
      current: current,
    );
  }

  @override
  Future<ProtocolCommitResult> finaliseSession({
    required int expectedRevision,
    required String sessionId,
  }) async {
    final current = (await _ensureReadyConfirmed())?.tuple;
    return ProtocolCommitRejected(
      reason: ProtocolRejectReason.guardFailed,
      current: current,
    );
  }

  @override
  Future<ProtocolCommitResult> reapDeadProcessStartLatch({
    required int expectedRevision,
    required String processId,
  }) async {
    final current = (await _ensureReadyConfirmed())?.tuple;
    return ProtocolCommitRejected(
      reason: ProtocolRejectReason.guardFailed,
      current: current,
    );
  }

  @override
  Future<ScannerLeaseAcquireResult> acquireForegroundLease({
    String? rollbackForAttemptId,
  }) async {
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
      leaseId: 'lease-$_leaseSeq',
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
    return const ScannerLeaseRejected(ScannerLeaseRejectReason.guardFailed);
  }

  @override
  Future<bool> markLeaseActive({required String leaseId}) async {
    final existing = _lease;
    if (existing == null || existing.leaseId != leaseId) return false;
    if (existing.phase == ScannerLeasePhase.active) return true;
    _lease = existing.copyWith(phase: ScannerLeasePhase.active);
    return true;
  }

  @override
  Future<bool> releaseLease({required String leaseId}) async {
    final existing = _lease;
    if (existing == null || existing.leaseId != leaseId) return false;
    _lease = null;
    return true;
  }

  @override
  Future<bool> releaseLeaseForEngine() async {
    final existing = _lease;
    if (existing == null ||
        existing.engineIncarnationId != _engineIncarnationId) {
      return false;
    }
    _lease = null;
    return true;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _changes.close();
  }

  Future<ProtocolCommitConfirmed?> _ensureReadyConfirmed() async {
    final ready = await _ensureReady();
    return ready is ProtocolCommitConfirmed ? ready : null;
  }

  Future<ProtocolCommitResult> _ensureReady() async {
    if (_persistenceUncertain && _privateAuthority != null) {
      return _persist(_privateAuthority!);
    }
    if (_lastConfirmed != null) {
      return ProtocolCommitConfirmed(_lastConfirmed!);
    }
    if (_prefs.containsKey(_keySchemaVersion)) {
      final loaded = _readTupleFromPrefs();
      if (loaded != null) {
        _lastConfirmed = loaded;
        _privateAuthority = loaded;
        return ProtocolCommitConfirmed(loaded);
      }
    }

    final legacy = _capturedLegacy ??= LegacyProtectionSnapshot(
      protectionEnabled: _prefs.getBool(_keyProtectionEnabled) ?? false,
      backgroundProtectionEnabled:
          _prefs.getBool(_keyLegacyBackgroundProtectionEnabled) ?? false,
      explicitlyStopped: _prefs.getBool(_keyLegacyExplicitlyStopped) ?? false,
    );
    final migrated = migrateFromLegacy(legacy);
    _privateAuthority = migrated;
    return _persist(migrated);
  }

  Future<ProtocolCommitResult> _mutate(
    _MutationOutcome Function(ProtectionProtocolTuple current) block,
  ) async {
    final ready = await _ensureReady();
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
      case _MutationAccepted(:final tuple, :final clearStopFence):
        if (tuple.revision == current.revision) {
          return ProtocolCommitConfirmed(current);
        }
        final persisted = await _persist(tuple);
        if (persisted is ProtocolCommitConfirmed && clearStopFence) {
          _stopFenceRaised = false;
        }
        return persisted;
      case _MutationStale(:final current):
        return ProtocolCommitStale(current);
      case _MutationRejected(:final reason, :final current):
        return ProtocolCommitRejected(reason: reason, current: current);
    }
  }

  Future<ProtocolCommitResult> _persist(
    ProtectionProtocolTuple intended,
  ) async {
    _privateAuthority = intended;
    final ok = _commitFn?.call(intended) ?? await _writePrefs(intended);
    if (ok) {
      _lastConfirmed = intended;
      _persistenceUncertain = false;
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
    _persistenceUncertain = true;
    return ProtocolCommitPersistenceUncertain(
      intendedTuple: intended,
      lastConfirmedTuple: _lastConfirmed,
    );
  }

  Future<bool> _writePrefs(ProtectionProtocolTuple tuple) async {
    // Foreground-only persistence: overall intent + preference + Stop + schema.
    await _prefs.setInt(_keySchemaVersion, tuple.schemaVersion);
    await _prefs.setInt(_keyRevision, tuple.revision);
    await _prefs.setBool(
      _keyBackgroundModePreferred,
      tuple.backgroundModePreferred,
    );
    await _prefs.setBool(_keyProtectionEnabled, tuple.protectionEnabled);
    await _prefs.setBool(_keyExplicitlyStopped, tuple.explicitlyStopped);
    // Legacy mirrors: background runtime stays inactive on this adapter.
    await _prefs.setBool(_keyLegacyBackgroundProtectionEnabled, false);
    await _prefs.setBool(
      _keyLegacyExplicitlyStopped,
      tuple.explicitlyStopped,
    );
    return true;
  }

  ProtectionProtocolTuple? _readTupleFromPrefs() {
    final schema = _prefs.getInt(_keySchemaVersion);
    if (schema == null || schema < 1) return null;
    return ProtectionProtocolTuple(
      schemaVersion: schema,
      revision: _prefs.getInt(_keyRevision) ?? 0,
      backgroundModePreferred:
          _prefs.getBool(_keyBackgroundModePreferred) ?? false,
      protectionEnabled: _prefs.getBool(_keyProtectionEnabled) ?? false,
      backgroundRuntimeEnabled: false,
      explicitlyStopped: _prefs.getBool(_keyExplicitlyStopped) ??
          _prefs.getBool(_keyLegacyExplicitlyStopped) ??
          false,
      activeTaskSessionId: null,
      activeTaskEpoch: null,
      activeTaskIncarnationId: null,
      nextTaskGeneration: 1,
      activeStartAttemptId: null,
      activeStartProcessId: null,
      taskPhase: ProtocolTaskPhase.none,
      nativeStartUnresolved: false,
    );
  }

  _MutationOutcome _setBackgroundModePreferred({
    required ProtectionProtocolTuple current,
    required int expectedRevision,
    required bool preferred,
  }) {
    final uncertain = _rejectIfUncertain(current);
    if (uncertain != null) return uncertain;
    final stale = _requireRevision(current, expectedRevision);
    if (stale != null) return stale;
    if (current.backgroundModePreferred == preferred) {
      return _MutationAccepted(current);
    }
    return _MutationAccepted(
      current.copyWith(
        revision: current.revision + 1,
        backgroundModePreferred: preferred,
      ),
    );
  }

  _MutationOutcome _beginForegroundIntent({
    required ProtectionProtocolTuple current,
    required int expectedRevision,
  }) {
    final uncertain = _rejectIfUncertain(current);
    if (uncertain != null) return uncertain;
    final stale = _requireRevision(current, expectedRevision);
    if (stale != null) return stale;

    var clearStopFence = false;
    if (_stopFenceRaised) {
      if (!current.explicitlyStopped) {
        return _MutationRejected(ProtocolRejectReason.stopFence, current);
      }
      clearStopFence = true;
    }

    return _MutationAccepted(
      _clearedSessionTuple(
        schemaVersion: current.schemaVersion,
        revision: current.revision + 1,
        backgroundModePreferred: current.backgroundModePreferred,
        protectionEnabled: true,
        explicitlyStopped: false,
        nextTaskGeneration: current.nextTaskGeneration,
      ),
      clearStopFence: clearStopFence,
    );
  }

  static ProtectionProtocolTuple migrateFromLegacy(
    LegacyProtectionSnapshot snapshot,
  ) {
    final explicitlyStopped = snapshot.explicitlyStopped;
    late final bool protectionEnabled;
    late final bool backgroundModePreferred;
    if (explicitlyStopped) {
      protectionEnabled = false;
      backgroundModePreferred = false;
    } else {
      protectionEnabled =
          snapshot.protectionEnabled || snapshot.backgroundProtectionEnabled;
      backgroundModePreferred = snapshot.backgroundProtectionEnabled;
    }
    return _clearedSessionTuple(
      schemaVersion: kProtectionProtocolSchemaVersion,
      revision: 1,
      backgroundModePreferred: backgroundModePreferred,
      protectionEnabled: protectionEnabled,
      explicitlyStopped: explicitlyStopped,
      nextTaskGeneration: 1,
    );
  }

  static ProtectionProtocolTuple _commitExplicitStop(
    ProtectionProtocolTuple current,
  ) {
    final phase = current.activeTaskSessionId != null
        ? ProtocolTaskPhase.cancelling
        : ProtocolTaskPhase.none;
    return current.copyWith(
      revision: current.revision + 1,
      protectionEnabled: false,
      backgroundRuntimeEnabled: false,
      explicitlyStopped: true,
      taskPhase: phase,
    );
  }

  static ProtectionProtocolTuple _clearedSessionTuple({
    required int schemaVersion,
    required int revision,
    required bool backgroundModePreferred,
    required bool protectionEnabled,
    required bool explicitlyStopped,
    required int nextTaskGeneration,
  }) {
    return ProtectionProtocolTuple(
      schemaVersion: schemaVersion,
      revision: revision,
      backgroundModePreferred: backgroundModePreferred,
      protectionEnabled: protectionEnabled,
      backgroundRuntimeEnabled: false,
      explicitlyStopped: explicitlyStopped,
      activeTaskSessionId: null,
      activeTaskEpoch: null,
      activeTaskIncarnationId: null,
      nextTaskGeneration: nextTaskGeneration,
      activeStartAttemptId: null,
      activeStartProcessId: null,
      taskPhase: ProtocolTaskPhase.none,
      nativeStartUnresolved: false,
    );
  }

  _MutationRejected? _rejectIfUncertain(ProtectionProtocolTuple current) {
    if (!_persistenceUncertain) return null;
    return _MutationRejected(
      ProtocolRejectReason.persistenceUncertain,
      current,
    );
  }

  _MutationStale? _requireRevision(
    ProtectionProtocolTuple current,
    int expectedRevision,
  ) {
    if (current.revision == expectedRevision) return null;
    return _MutationStale(current);
  }
}

sealed class _MutationOutcome {
  const _MutationOutcome();
}

final class _MutationAccepted extends _MutationOutcome {
  const _MutationAccepted(this.tuple, {this.clearStopFence = false});
  final ProtectionProtocolTuple tuple;
  final bool clearStopFence;
}

final class _MutationStale extends _MutationOutcome {
  const _MutationStale(this.current);
  final ProtectionProtocolTuple current;
}

final class _MutationRejected extends _MutationOutcome {
  const _MutationRejected(this.reason, this.current);
  final ProtocolRejectReason reason;
  final ProtectionProtocolTuple? current;
}
