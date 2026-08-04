package app.unrecorded.unrecorded_mobile.protocol

/**
 * Authoritative durable protection tuple on Android.
 * See plan sections 5–6 (issue-92-replacement).
 */
data class ProtectionProtocolTuple(
    val schemaVersion: Int,
    val revision: Long,
    val backgroundModePreferred: Boolean,
    val protectionEnabled: Boolean,
    val backgroundRuntimeEnabled: Boolean,
    val explicitlyStopped: Boolean,
    val activeTaskSessionId: String?,
    val activeTaskEpoch: Long?,
    val activeTaskIncarnationId: String?,
    val nextTaskGeneration: Long,
    val activeStartAttemptId: String?,
    val activeStartProcessId: String?,
    val taskPhase: TaskPhase,
    val nativeStartUnresolved: Boolean,
) {
    companion object {
        const val CURRENT_SCHEMA_VERSION: Int = 1
    }
}

enum class TaskPhase(val wireName: String) {
    NONE("none"),
    ALLOCATED("allocated"),
    SCANNER_READY("scannerReady"),
    CANCELLING("cancelling");

    companion object {
        fun fromWire(value: String?): TaskPhase {
            if (value == null) return NONE
            return entries.firstOrNull { it.wireName == value } ?: NONE
        }
    }
}

/** Immutable capture of the three pre-protocol preference keys. */
data class LegacySnapshot(
    val protectionEnabled: Boolean,
    val backgroundProtectionEnabled: Boolean,
    val explicitlyStopped: Boolean,
)

enum class EngineKind {
    MAIN,
    TASK,
}

enum class ScannerLeaseOwnerKind {
    FOREGROUND,
    BACKGROUND,
}

enum class ScannerLeasePhase {
    STARTING,
    ACTIVE,
    STOPPING,
}

data class ScannerLease(
    val ownerKind: ScannerLeaseOwnerKind,
    val leaseId: String,
    val engineIncarnationId: String,
    val taskSessionId: String?,
    val taskEpoch: Long?,
    val phase: ScannerLeasePhase,
)

/** Pure outcome of a CAS / fence-checked mutation before persistence. */
sealed class ProtocolMutationOutcome {
    data class Accepted(
        val tuple: ProtectionProtocolTuple,
        /** When true, the repository should clear the in-memory Stop fence after a confirmed commit. */
        val clearStopFence: Boolean = false,
        /** Attempt IDs to install as cancellation fences before waiting on the serial queue. */
        val raiseAttemptFenceIds: Set<String> = emptySet(),
    ) : ProtocolMutationOutcome()

    data class Stale(
        val current: ProtectionProtocolTuple,
    ) : ProtocolMutationOutcome()

    data class Rejected(
        val reason: ProtocolRejectReason,
        val current: ProtectionProtocolTuple?,
    ) : ProtocolMutationOutcome()
}

enum class ProtocolRejectReason {
    STOP_FENCE,
    ATTEMPT_FENCE,
    PERSISTENCE_UNCERTAIN,
    GUARD_FAILED,
}

/** Result after attempting a SharedPreferences commit. */
sealed class ProtocolCommitResult {
    data class Confirmed(val tuple: ProtectionProtocolTuple) : ProtocolCommitResult()

    data class PersistenceUncertain(
        val intendedTuple: ProtectionProtocolTuple?,
        val lastConfirmedTuple: ProtectionProtocolTuple?,
    ) : ProtocolCommitResult()

    data class Stale(val current: ProtectionProtocolTuple) : ProtocolCommitResult()

    data class Rejected(
        val reason: ProtocolRejectReason,
        val current: ProtectionProtocolTuple?,
    ) : ProtocolCommitResult()
}

sealed class ScannerLeaseAcquireResult {
    data class Acquired(val lease: ScannerLease) : ScannerLeaseAcquireResult()

    data class Rejected(val reason: ScannerLeaseRejectReason) : ScannerLeaseAcquireResult()
}

enum class ScannerLeaseRejectReason {
    STOP_FENCE,
    PERSISTENCE_UNCERTAIN,
    LEASE_HELD,
    GUARD_FAILED,
    ENGINE_ABSENT,
}
