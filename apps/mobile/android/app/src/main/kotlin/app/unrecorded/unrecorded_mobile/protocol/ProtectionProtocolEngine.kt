package app.unrecorded.unrecorded_mobile.protocol

/**
 * Pure, Android-free protocol logic: legacy migration, CAS mutations, Stop/attempt fences.
 * Unit-testable without the Android framework.
 */
object ProtectionProtocolEngine {

    fun migrateFromLegacy(snapshot: LegacySnapshot): ProtectionProtocolTuple {
        val explicitlyStopped = snapshot.explicitlyStopped
        val protectionEnabled: Boolean
        if (explicitlyStopped) {
            // Explicit Stop dominates overall intent.
            protectionEnabled = false
        } else {
            protectionEnabled =
                snapshot.protectionEnabled || snapshot.backgroundProtectionEnabled
        }
        return clearedSessionTuple(
            schemaVersion = ProtectionProtocolTuple.CURRENT_SCHEMA_VERSION,
            revision = 1L,
            backgroundModePreferred = true,
            protectionEnabled = protectionEnabled,
            explicitlyStopped = explicitlyStopped,
            nextTaskGeneration = 1L,
        )
    }

    fun clearedSessionTuple(
        schemaVersion: Int,
        revision: Long,
        backgroundModePreferred: Boolean,
        protectionEnabled: Boolean,
        explicitlyStopped: Boolean,
        nextTaskGeneration: Long,
    ): ProtectionProtocolTuple {
        return ProtectionProtocolTuple(
            schemaVersion = schemaVersion,
            revision = revision,
            backgroundModePreferred = backgroundModePreferred,
            protectionEnabled = protectionEnabled,
            backgroundRuntimeEnabled = false,
            explicitlyStopped = explicitlyStopped,
            activeTaskSessionId = null,
            activeTaskEpoch = null,
            activeTaskIncarnationId = null,
            nextTaskGeneration = nextTaskGeneration,
            activeStartAttemptId = null,
            activeStartProcessId = null,
            taskPhase = TaskPhase.NONE,
            nativeStartUnresolved = false,
        )
    }

    fun setBackgroundModePreferred(
        current: ProtectionProtocolTuple,
        expectedRevision: Long,
        preferred: Boolean,
        stopFenceRaised: Boolean,
        persistenceUncertain: Boolean,
    ): ProtocolMutationOutcome {
        rejectIfUncertain(persistenceUncertain, current)?.let { return it }
        // Preference-only changes cannot enable mechanics and remain allowed under Stop fence.
        requireRevision(current, expectedRevision)?.let { return it }
        if (current.backgroundModePreferred == preferred) {
            return ProtocolMutationOutcome.Accepted(current)
        }
        return ProtocolMutationOutcome.Accepted(
            current.copy(
                revision = current.revision + 1,
                backgroundModePreferred = preferred,
            ),
        )
    }

    fun beginForegroundIntent(
        current: ProtectionProtocolTuple,
        expectedRevision: Long,
        stopFenceRaised: Boolean,
        persistenceUncertain: Boolean,
    ): ProtocolMutationOutcome {
        rejectIfUncertain(persistenceUncertain, current)?.let { return it }
        requireRevision(current, expectedRevision)?.let { return it }

        val clearStopFence: Boolean
        if (stopFenceRaised) {
            // Enable may clear the fence only after a confirmed Stop tuple at this revision.
            if (!current.explicitlyStopped) {
                return ProtocolMutationOutcome.Rejected(
                    ProtocolRejectReason.STOP_FENCE,
                    current,
                )
            }
            clearStopFence = true
        } else {
            clearStopFence = false
        }

        val next = clearedSessionTuple(
            schemaVersion = current.schemaVersion,
            revision = current.revision + 1,
            backgroundModePreferred = current.backgroundModePreferred,
            protectionEnabled = true,
            explicitlyStopped = false,
            nextTaskGeneration = current.nextTaskGeneration,
        )
        return ProtocolMutationOutcome.Accepted(next, clearStopFence = clearStopFence)
    }

    fun allocateBackgroundSession(
        current: ProtectionProtocolTuple,
        expectedRevision: Long,
        attemptId: String,
        processId: String,
        stopFenceRaised: Boolean,
        cancelledAttemptIds: Set<String>,
        persistenceUncertain: Boolean,
    ): ProtocolMutationOutcome {
        rejectIfUncertain(persistenceUncertain, current)?.let { return it }
        if (stopFenceRaised) {
            return ProtocolMutationOutcome.Rejected(ProtocolRejectReason.STOP_FENCE, current)
        }
        if (attemptId in cancelledAttemptIds) {
            return ProtocolMutationOutcome.Rejected(ProtocolRejectReason.ATTEMPT_FENCE, current)
        }
        requireRevision(current, expectedRevision)?.let { return it }
        if (!current.protectionEnabled || current.explicitlyStopped) {
            return ProtocolMutationOutcome.Rejected(ProtocolRejectReason.GUARD_FAILED, current)
        }
        if (current.backgroundRuntimeEnabled || current.activeTaskSessionId != null) {
            return ProtocolMutationOutcome.Rejected(ProtocolRejectReason.GUARD_FAILED, current)
        }

        val generation = current.nextTaskGeneration
        val sessionId = "task-$generation"
        val next = current.copy(
            revision = current.revision + 1,
            backgroundRuntimeEnabled = true,
            explicitlyStopped = false,
            activeTaskSessionId = sessionId,
            activeTaskEpoch = current.revision + 1,
            activeTaskIncarnationId = null,
            nextTaskGeneration = generation + 1,
            activeStartAttemptId = attemptId,
            activeStartProcessId = processId,
            taskPhase = TaskPhase.ALLOCATED,
            nativeStartUnresolved = true,
        )
        return ProtocolMutationOutcome.Accepted(next)
    }

    /**
     * Attempt-scoped cancellation: installs a fence for [attemptId] and, when allocation already
     * committed for that attempt, disables runtime while retaining the session tombstone.
     */
    fun cancelBackgroundAttempt(
        current: ProtectionProtocolTuple,
        attemptId: String,
        stopFenceRaised: Boolean,
        persistenceUncertain: Boolean,
    ): ProtocolMutationOutcome {
        rejectIfUncertain(persistenceUncertain, current)?.let { return it }
        // Cancellation preserves overall intent; Stop fence still blocks enabling, but
        // cancelling a matching attempt remains allowed for cleanup.
        if (stopFenceRaised && current.activeStartAttemptId != attemptId) {
            return ProtocolMutationOutcome.Rejected(ProtocolRejectReason.STOP_FENCE, current)
        }

        if (current.activeStartAttemptId != attemptId) {
            // Allocation has not run (or already superseded). Fence alone rejects a later allocate.
            return ProtocolMutationOutcome.Accepted(
                current,
                raiseAttemptFenceIds = setOf(attemptId),
            )
        }

        val next = current.copy(
            revision = current.revision + 1,
            backgroundRuntimeEnabled = false,
            taskPhase = TaskPhase.CANCELLING,
            // Retain session tombstone / start fields for cleanup fencing.
        )
        return ProtocolMutationOutcome.Accepted(
            next,
            raiseAttemptFenceIds = setOf(attemptId),
        )
    }

    /**
     * Global high-priority Stop. Does not require expectedRevision.
     * Caller raises the in-memory Stop fence before invoking this.
     */
    fun commitExplicitStop(current: ProtectionProtocolTuple): ProtectionProtocolTuple {
        val phase =
            if (current.activeTaskSessionId != null) TaskPhase.CANCELLING else TaskPhase.NONE
        return current.copy(
            revision = current.revision + 1,
            protectionEnabled = false,
            backgroundRuntimeEnabled = false,
            explicitlyStopped = true,
            taskPhase = phase,
            // Preserve backgroundModePreferred and session identity for cleanup.
        )
    }

    /**
     * Background → foreground intent: preferred false, runtime false, phase cancelling when a
     * session tombstone remains. Preserves overall [ProtectionProtocolTuple.protectionEnabled].
     */
    fun switchToForegroundIntent(
        current: ProtectionProtocolTuple,
        expectedRevision: Long,
        stopFenceRaised: Boolean,
        persistenceUncertain: Boolean,
    ): ProtocolMutationOutcome {
        rejectIfUncertain(persistenceUncertain, current)?.let { return it }
        if (stopFenceRaised) {
            return ProtocolMutationOutcome.Rejected(ProtocolRejectReason.STOP_FENCE, current)
        }
        requireRevision(current, expectedRevision)?.let { return it }
        if (current.explicitlyStopped) {
            return ProtocolMutationOutcome.Rejected(ProtocolRejectReason.GUARD_FAILED, current)
        }

        val phase =
            if (current.activeTaskSessionId != null) TaskPhase.CANCELLING else TaskPhase.NONE
        val next = current.copy(
            revision = current.revision + 1,
            backgroundModePreferred = false,
            backgroundRuntimeEnabled = false,
            taskPhase = phase,
        )
        return ProtocolMutationOutcome.Accepted(next)
    }

    fun claimTaskIncarnation(
        current: ProtectionProtocolTuple,
        expectedRevision: Long,
        sessionId: String,
        incarnationId: String,
        stopFenceRaised: Boolean,
        persistenceUncertain: Boolean,
    ): ProtocolMutationOutcome {
        rejectIfUncertain(persistenceUncertain, current)?.let { return it }
        if (stopFenceRaised) {
            return ProtocolMutationOutcome.Rejected(ProtocolRejectReason.STOP_FENCE, current)
        }
        requireRevision(current, expectedRevision)?.let { return it }
        if (!current.backgroundRuntimeEnabled ||
            current.activeTaskSessionId != sessionId
        ) {
            return ProtocolMutationOutcome.Rejected(ProtocolRejectReason.GUARD_FAILED, current)
        }
        if (current.taskPhase == TaskPhase.CANCELLING || current.explicitlyStopped) {
            return ProtocolMutationOutcome.Rejected(ProtocolRejectReason.GUARD_FAILED, current)
        }
        if (current.activeTaskIncarnationId == incarnationId) {
            return ProtocolMutationOutcome.Accepted(current)
        }
        val next = current.copy(
            revision = current.revision + 1,
            activeTaskIncarnationId = incarnationId,
        )
        return ProtocolMutationOutcome.Accepted(next)
    }

    fun markTaskScannerReady(
        current: ProtectionProtocolTuple,
        expectedRevision: Long,
        sessionId: String,
        epoch: Long,
        incarnationId: String,
        stopFenceRaised: Boolean,
        persistenceUncertain: Boolean,
    ): ProtocolMutationOutcome {
        rejectIfUncertain(persistenceUncertain, current)?.let { return it }
        if (stopFenceRaised) {
            return ProtocolMutationOutcome.Rejected(ProtocolRejectReason.STOP_FENCE, current)
        }
        requireRevision(current, expectedRevision)?.let { return it }
        if (current.activeTaskSessionId != sessionId ||
            current.activeTaskEpoch != epoch ||
            current.activeTaskIncarnationId != incarnationId ||
            !current.backgroundRuntimeEnabled
        ) {
            return ProtocolMutationOutcome.Rejected(ProtocolRejectReason.GUARD_FAILED, current)
        }
        if (current.taskPhase == TaskPhase.SCANNER_READY) {
            return ProtocolMutationOutcome.Accepted(current)
        }
        return ProtocolMutationOutcome.Accepted(
            current.copy(
                revision = current.revision + 1,
                taskPhase = TaskPhase.SCANNER_READY,
            ),
        )
    }

    fun markNativeStartResolved(
        current: ProtectionProtocolTuple,
        expectedRevision: Long,
        attemptId: String,
        processId: String,
        persistenceUncertain: Boolean,
    ): ProtocolMutationOutcome {
        rejectIfUncertain(persistenceUncertain, current)?.let { return it }
        requireRevision(current, expectedRevision)?.let { return it }
        if (current.activeStartAttemptId != attemptId ||
            current.activeStartProcessId != processId
        ) {
            return ProtocolMutationOutcome.Rejected(ProtocolRejectReason.GUARD_FAILED, current)
        }
        if (!current.nativeStartUnresolved) {
            return ProtocolMutationOutcome.Accepted(current)
        }
        return ProtocolMutationOutcome.Accepted(
            current.copy(
                revision = current.revision + 1,
                nativeStartUnresolved = false,
            ),
        )
    }

    /**
     * Clears [ProtectionProtocolTuple.nativeStartUnresolved] when the recorded start process is
     * not [currentProcessId] (the old Dart Future died with that process).
     */
    fun reapDeadProcessStartLatch(
        current: ProtectionProtocolTuple,
        expectedRevision: Long,
        currentProcessId: String,
        persistenceUncertain: Boolean,
    ): ProtocolMutationOutcome {
        rejectIfUncertain(persistenceUncertain, current)?.let { return it }
        requireRevision(current, expectedRevision)?.let { return it }
        if (!current.nativeStartUnresolved) {
            return ProtocolMutationOutcome.Accepted(current)
        }
        val recorded = current.activeStartProcessId
        if (recorded == null || recorded == currentProcessId) {
            return ProtocolMutationOutcome.Rejected(ProtocolRejectReason.GUARD_FAILED, current)
        }
        return ProtocolMutationOutcome.Accepted(
            current.copy(
                revision = current.revision + 1,
                nativeStartUnresolved = false,
            ),
        )
    }

    fun finaliseSession(
        current: ProtectionProtocolTuple,
        expectedRevision: Long,
        sessionId: String,
        persistenceUncertain: Boolean,
    ): ProtocolMutationOutcome {
        rejectIfUncertain(persistenceUncertain, current)?.let { return it }
        requireRevision(current, expectedRevision)?.let { return it }
        if (current.activeTaskSessionId != sessionId) {
            return ProtocolMutationOutcome.Rejected(ProtocolRejectReason.GUARD_FAILED, current)
        }
        return ProtocolMutationOutcome.Accepted(
            clearedSessionTuple(
                schemaVersion = current.schemaVersion,
                revision = current.revision + 1,
                backgroundModePreferred = current.backgroundModePreferred,
                protectionEnabled = current.protectionEnabled,
                explicitlyStopped = current.explicitlyStopped,
                nextTaskGeneration = current.nextTaskGeneration,
            ),
        )
    }

    private fun rejectIfUncertain(
        persistenceUncertain: Boolean,
        current: ProtectionProtocolTuple?,
    ): ProtocolMutationOutcome.Rejected? {
        if (!persistenceUncertain) return null
        return ProtocolMutationOutcome.Rejected(
            ProtocolRejectReason.PERSISTENCE_UNCERTAIN,
            current,
        )
    }

    private fun requireRevision(
        current: ProtectionProtocolTuple,
        expectedRevision: Long,
    ): ProtocolMutationOutcome.Stale? {
        if (current.revision == expectedRevision) return null
        return ProtocolMutationOutcome.Stale(current)
    }
}
