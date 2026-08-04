// Wire-compatible Dart models for `app.unrecorded/protection_protocol`.
//
// Field names and enum wire strings match the Android MethodChannel maps.

const int kProtectionProtocolSchemaVersion = 1;

enum ProtocolTaskPhase {
  none('none'),
  allocated('allocated'),
  scannerReady('scannerReady'),
  cancelling('cancelling');

  const ProtocolTaskPhase(this.wireName);
  final String wireName;

  static ProtocolTaskPhase fromWire(Object? value) {
    if (value is! String) return ProtocolTaskPhase.none;
    for (final phase in ProtocolTaskPhase.values) {
      if (phase.wireName == value) return phase;
    }
    return ProtocolTaskPhase.none;
  }
}

enum ProtocolEngineKind {
  main('MAIN'),
  task('TASK');

  const ProtocolEngineKind(this.wireName);
  final String wireName;

  static ProtocolEngineKind fromWire(Object? value) {
    if (value is! String) return ProtocolEngineKind.main;
    for (final kind in ProtocolEngineKind.values) {
      if (kind.wireName == value) return kind;
    }
    return ProtocolEngineKind.main;
  }
}

enum ScannerLeaseOwnerKind {
  foreground('FOREGROUND'),
  background('BACKGROUND');

  const ScannerLeaseOwnerKind(this.wireName);
  final String wireName;

  static ScannerLeaseOwnerKind fromWire(Object? value) {
    if (value is! String) {
      throw ArgumentError.value(value, 'ownerKind', 'unknown lease owner');
    }
    for (final kind in ScannerLeaseOwnerKind.values) {
      if (kind.wireName == value) return kind;
    }
    throw ArgumentError.value(value, 'ownerKind', 'unknown lease owner');
  }
}

enum ScannerLeasePhase {
  starting('STARTING'),
  active('ACTIVE'),
  stopping('STOPPING');

  const ScannerLeasePhase(this.wireName);
  final String wireName;

  static ScannerLeasePhase fromWire(Object? value) {
    if (value is! String) {
      throw ArgumentError.value(value, 'phase', 'unknown lease phase');
    }
    for (final phase in ScannerLeasePhase.values) {
      if (phase.wireName == value) return phase;
    }
    throw ArgumentError.value(value, 'phase', 'unknown lease phase');
  }
}

enum ProtocolRejectReason {
  stopFence('STOP_FENCE'),
  attemptFence('ATTEMPT_FENCE'),
  persistenceUncertain('PERSISTENCE_UNCERTAIN'),
  guardFailed('GUARD_FAILED');

  const ProtocolRejectReason(this.wireName);
  final String wireName;

  static ProtocolRejectReason fromWire(Object? value) {
    if (value is! String) {
      throw ArgumentError.value(value, 'reason', 'unknown reject reason');
    }
    for (final reason in ProtocolRejectReason.values) {
      if (reason.wireName == value) return reason;
    }
    throw ArgumentError.value(value, 'reason', 'unknown reject reason');
  }
}

enum ScannerLeaseRejectReason {
  stopFence('STOP_FENCE'),
  persistenceUncertain('PERSISTENCE_UNCERTAIN'),
  leaseHeld('LEASE_HELD'),
  guardFailed('GUARD_FAILED'),
  engineAbsent('ENGINE_ABSENT');

  const ScannerLeaseRejectReason(this.wireName);
  final String wireName;

  static ScannerLeaseRejectReason fromWire(Object? value) {
    if (value is! String) {
      throw ArgumentError.value(value, 'reason', 'unknown lease reject');
    }
    for (final reason in ScannerLeaseRejectReason.values) {
      if (reason.wireName == value) return reason;
    }
    throw ArgumentError.value(value, 'reason', 'unknown lease reject');
  }
}

/// Authoritative durable protection tuple.
class ProtectionProtocolTuple {
  const ProtectionProtocolTuple({
    required this.schemaVersion,
    required this.revision,
    required this.backgroundModePreferred,
    required this.protectionEnabled,
    required this.backgroundRuntimeEnabled,
    required this.explicitlyStopped,
    required this.activeTaskSessionId,
    required this.activeTaskEpoch,
    required this.activeTaskIncarnationId,
    required this.nextTaskGeneration,
    required this.activeStartAttemptId,
    required this.activeStartProcessId,
    required this.taskPhase,
    required this.nativeStartUnresolved,
  });

  final int schemaVersion;
  final int revision;
  final bool backgroundModePreferred;
  final bool protectionEnabled;
  final bool backgroundRuntimeEnabled;
  final bool explicitlyStopped;
  final String? activeTaskSessionId;
  final int? activeTaskEpoch;
  final String? activeTaskIncarnationId;
  final int nextTaskGeneration;
  final String? activeStartAttemptId;
  final String? activeStartProcessId;
  final ProtocolTaskPhase taskPhase;
  final bool nativeStartUnresolved;

  ProtectionProtocolTuple copyWith({
    int? schemaVersion,
    int? revision,
    bool? backgroundModePreferred,
    bool? protectionEnabled,
    bool? backgroundRuntimeEnabled,
    bool? explicitlyStopped,
    Object? activeTaskSessionId = _unset,
    Object? activeTaskEpoch = _unset,
    Object? activeTaskIncarnationId = _unset,
    int? nextTaskGeneration,
    Object? activeStartAttemptId = _unset,
    Object? activeStartProcessId = _unset,
    ProtocolTaskPhase? taskPhase,
    bool? nativeStartUnresolved,
  }) {
    return ProtectionProtocolTuple(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      revision: revision ?? this.revision,
      backgroundModePreferred:
          backgroundModePreferred ?? this.backgroundModePreferred,
      protectionEnabled: protectionEnabled ?? this.protectionEnabled,
      backgroundRuntimeEnabled:
          backgroundRuntimeEnabled ?? this.backgroundRuntimeEnabled,
      explicitlyStopped: explicitlyStopped ?? this.explicitlyStopped,
      activeTaskSessionId: identical(activeTaskSessionId, _unset)
          ? this.activeTaskSessionId
          : activeTaskSessionId as String?,
      activeTaskEpoch: identical(activeTaskEpoch, _unset)
          ? this.activeTaskEpoch
          : activeTaskEpoch as int?,
      activeTaskIncarnationId: identical(activeTaskIncarnationId, _unset)
          ? this.activeTaskIncarnationId
          : activeTaskIncarnationId as String?,
      nextTaskGeneration: nextTaskGeneration ?? this.nextTaskGeneration,
      activeStartAttemptId: identical(activeStartAttemptId, _unset)
          ? this.activeStartAttemptId
          : activeStartAttemptId as String?,
      activeStartProcessId: identical(activeStartProcessId, _unset)
          ? this.activeStartProcessId
          : activeStartProcessId as String?,
      taskPhase: taskPhase ?? this.taskPhase,
      nativeStartUnresolved:
          nativeStartUnresolved ?? this.nativeStartUnresolved,
    );
  }

  Map<String, Object?> toWireMap() => {
        'schemaVersion': schemaVersion,
        'revision': revision,
        'backgroundModePreferred': backgroundModePreferred,
        'protectionEnabled': protectionEnabled,
        'backgroundRuntimeEnabled': backgroundRuntimeEnabled,
        'explicitlyStopped': explicitlyStopped,
        'activeTaskSessionId': activeTaskSessionId,
        'activeTaskEpoch': activeTaskEpoch,
        'activeTaskIncarnationId': activeTaskIncarnationId,
        'nextTaskGeneration': nextTaskGeneration,
        'activeStartAttemptId': activeStartAttemptId,
        'activeStartProcessId': activeStartProcessId,
        'taskPhase': taskPhase.wireName,
        'nativeStartUnresolved': nativeStartUnresolved,
      };

  static ProtectionProtocolTuple? fromWireMap(Object? raw) {
    if (raw == null) return null;
    if (raw is! Map) {
      throw ArgumentError.value(raw, 'tuple', 'expected map');
    }
    final map = Map<String, Object?>.from(raw);
    return ProtectionProtocolTuple(
      schemaVersion: _asInt(map['schemaVersion']),
      revision: _asInt(map['revision']),
      backgroundModePreferred: map['backgroundModePreferred'] as bool,
      protectionEnabled: map['protectionEnabled'] as bool,
      backgroundRuntimeEnabled: map['backgroundRuntimeEnabled'] as bool,
      explicitlyStopped: map['explicitlyStopped'] as bool,
      activeTaskSessionId: map['activeTaskSessionId'] as String?,
      activeTaskEpoch: _asNullableInt(map['activeTaskEpoch']),
      activeTaskIncarnationId: map['activeTaskIncarnationId'] as String?,
      nextTaskGeneration: _asInt(map['nextTaskGeneration']),
      activeStartAttemptId: map['activeStartAttemptId'] as String?,
      activeStartProcessId: map['activeStartProcessId'] as String?,
      taskPhase: ProtocolTaskPhase.fromWire(map['taskPhase']),
      nativeStartUnresolved: map['nativeStartUnresolved'] as bool,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ProtectionProtocolTuple &&
        other.schemaVersion == schemaVersion &&
        other.revision == revision &&
        other.backgroundModePreferred == backgroundModePreferred &&
        other.protectionEnabled == protectionEnabled &&
        other.backgroundRuntimeEnabled == backgroundRuntimeEnabled &&
        other.explicitlyStopped == explicitlyStopped &&
        other.activeTaskSessionId == activeTaskSessionId &&
        other.activeTaskEpoch == activeTaskEpoch &&
        other.activeTaskIncarnationId == activeTaskIncarnationId &&
        other.nextTaskGeneration == nextTaskGeneration &&
        other.activeStartAttemptId == activeStartAttemptId &&
        other.activeStartProcessId == activeStartProcessId &&
        other.taskPhase == taskPhase &&
        other.nativeStartUnresolved == nativeStartUnresolved;
  }

  @override
  int get hashCode => Object.hash(
        schemaVersion,
        revision,
        backgroundModePreferred,
        protectionEnabled,
        backgroundRuntimeEnabled,
        explicitlyStopped,
        activeTaskSessionId,
        activeTaskEpoch,
        activeTaskIncarnationId,
        nextTaskGeneration,
        activeStartAttemptId,
        activeStartProcessId,
        taskPhase,
        nativeStartUnresolved,
      );
}

class ScannerLease {
  const ScannerLease({
    required this.ownerKind,
    required this.leaseId,
    required this.engineIncarnationId,
    required this.taskSessionId,
    required this.taskEpoch,
    required this.phase,
  });

  final ScannerLeaseOwnerKind ownerKind;
  final String leaseId;
  final String engineIncarnationId;
  final String? taskSessionId;
  final int? taskEpoch;
  final ScannerLeasePhase phase;

  ScannerLease copyWith({ScannerLeasePhase? phase}) {
    return ScannerLease(
      ownerKind: ownerKind,
      leaseId: leaseId,
      engineIncarnationId: engineIncarnationId,
      taskSessionId: taskSessionId,
      taskEpoch: taskEpoch,
      phase: phase ?? this.phase,
    );
  }

  Map<String, Object?> toWireMap() => {
        'ownerKind': ownerKind.wireName,
        'leaseId': leaseId,
        'engineIncarnationId': engineIncarnationId,
        'taskSessionId': taskSessionId,
        'taskEpoch': taskEpoch,
        'phase': phase.wireName,
      };

  static ScannerLease? fromWireMap(Object? raw) {
    if (raw == null) return null;
    if (raw is! Map) {
      throw ArgumentError.value(raw, 'lease', 'expected map');
    }
    final map = Map<String, Object?>.from(raw);
    return ScannerLease(
      ownerKind: ScannerLeaseOwnerKind.fromWire(map['ownerKind']),
      leaseId: map['leaseId'] as String,
      engineIncarnationId: map['engineIncarnationId'] as String,
      taskSessionId: map['taskSessionId'] as String?,
      taskEpoch: _asNullableInt(map['taskEpoch']),
      phase: ScannerLeasePhase.fromWire(map['phase']),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ScannerLease &&
        other.ownerKind == ownerKind &&
        other.leaseId == leaseId &&
        other.engineIncarnationId == engineIncarnationId &&
        other.taskSessionId == taskSessionId &&
        other.taskEpoch == taskEpoch &&
        other.phase == phase;
  }

  @override
  int get hashCode => Object.hash(
        ownerKind,
        leaseId,
        engineIncarnationId,
        taskSessionId,
        taskEpoch,
        phase,
      );
}

/// Snapshot returned by `getState`.
class ProtectionProtocolState {
  const ProtectionProtocolState({
    required this.engineIncarnationId,
    required this.engineKind,
    required this.processInstanceId,
    required this.persistenceUncertain,
    required this.stopFenceRaised,
    required this.tuple,
    required this.lease,
  });

  final String engineIncarnationId;
  final ProtocolEngineKind engineKind;
  final String processInstanceId;
  final bool persistenceUncertain;
  final bool stopFenceRaised;
  final ProtectionProtocolTuple? tuple;
  final ScannerLease? lease;

  static ProtectionProtocolState fromWireMap(Map<Object?, Object?> raw) {
    final map = Map<String, Object?>.from(raw);
    return ProtectionProtocolState(
      engineIncarnationId: map['engineIncarnationId'] as String,
      engineKind: ProtocolEngineKind.fromWire(map['engineKind']),
      processInstanceId: map['processInstanceId'] as String,
      persistenceUncertain: map['persistenceUncertain'] as bool,
      stopFenceRaised: map['stopFenceRaised'] as bool,
      tuple: ProtectionProtocolTuple.fromWireMap(map['tuple']),
      lease: ScannerLease.fromWireMap(map['lease']),
    );
  }
}

/// Best-effort revision ping from native (`onProtocolChanged`).
class ProtocolChangeNotification {
  const ProtocolChangeNotification({
    required this.revision,
    required this.engineIncarnationId,
  });

  final int revision;
  final String engineIncarnationId;
}

sealed class ProtocolCommitResult {
  const ProtocolCommitResult();

  static ProtocolCommitResult fromWireMap(Map<Object?, Object?> raw) {
    final map = Map<String, Object?>.from(raw);
    switch (map['status'] as String) {
      case 'confirmed':
        return ProtocolCommitConfirmed(
          ProtectionProtocolTuple.fromWireMap(map['tuple'])!,
        );
      case 'persistenceUncertain':
        return ProtocolCommitPersistenceUncertain(
          intendedTuple:
              ProtectionProtocolTuple.fromWireMap(map['intendedTuple']),
          lastConfirmedTuple:
              ProtectionProtocolTuple.fromWireMap(map['lastConfirmedTuple']),
        );
      case 'stale':
        return ProtocolCommitStale(
          ProtectionProtocolTuple.fromWireMap(map['tuple'])!,
        );
      case 'rejected':
        return ProtocolCommitRejected(
          reason: ProtocolRejectReason.fromWire(map['reason']),
          current: ProtectionProtocolTuple.fromWireMap(map['tuple']),
        );
      default:
        throw ArgumentError.value(map['status'], 'status', 'unknown commit');
    }
  }
}

final class ProtocolCommitConfirmed extends ProtocolCommitResult {
  const ProtocolCommitConfirmed(this.tuple);
  final ProtectionProtocolTuple tuple;
}

final class ProtocolCommitPersistenceUncertain extends ProtocolCommitResult {
  const ProtocolCommitPersistenceUncertain({
    required this.intendedTuple,
    required this.lastConfirmedTuple,
  });
  final ProtectionProtocolTuple? intendedTuple;
  final ProtectionProtocolTuple? lastConfirmedTuple;
}

final class ProtocolCommitStale extends ProtocolCommitResult {
  const ProtocolCommitStale(this.current);
  final ProtectionProtocolTuple current;
}

final class ProtocolCommitRejected extends ProtocolCommitResult {
  const ProtocolCommitRejected({required this.reason, required this.current});
  final ProtocolRejectReason reason;
  final ProtectionProtocolTuple? current;
}

sealed class ScannerLeaseAcquireResult {
  const ScannerLeaseAcquireResult();

  static ScannerLeaseAcquireResult fromWireMap(Map<Object?, Object?> raw) {
    final map = Map<String, Object?>.from(raw);
    switch (map['status'] as String) {
      case 'acquired':
        return ScannerLeaseAcquired(ScannerLease.fromWireMap(map['lease'])!);
      case 'rejected':
        return ScannerLeaseRejected(
          ScannerLeaseRejectReason.fromWire(map['reason']),
        );
      default:
        throw ArgumentError.value(map['status'], 'status', 'unknown lease');
    }
  }
}

final class ScannerLeaseAcquired extends ScannerLeaseAcquireResult {
  const ScannerLeaseAcquired(this.lease);
  final ScannerLease lease;
}

final class ScannerLeaseRejected extends ScannerLeaseAcquireResult {
  const ScannerLeaseRejected(this.reason);
  final ScannerLeaseRejectReason reason;
}

/// Legacy three-key snapshot used by schema migration.
class LegacyProtectionSnapshot {
  const LegacyProtectionSnapshot({
    required this.protectionEnabled,
    required this.backgroundProtectionEnabled,
    required this.explicitlyStopped,
  });

  final bool protectionEnabled;
  final bool backgroundProtectionEnabled;
  final bool explicitlyStopped;
}

const Object _unset = Object();

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw ArgumentError.value(value, 'value', 'expected int');
}

int? _asNullableInt(Object? value) {
  if (value == null) return null;
  return _asInt(value);
}
