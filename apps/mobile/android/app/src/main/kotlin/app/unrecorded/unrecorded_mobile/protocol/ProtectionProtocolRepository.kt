package app.unrecorded.unrecorded_mobile.protocol

import java.util.UUID
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

/**
 * Application-scoped owner of the protection protocol: fair lock, synchronous commits,
 * last-confirmed tuple, Stop/attempt fences, engine registry, and exclusive scanner lease.
 */
class ProtectionProtocolRepository(
    private val persistence: ProtectionProtocolPersistence,
    private val commitFn: (ProtectionProtocolTuple) -> Boolean = persistence::writeFullTuple,
    processInstanceId: String = UUID.randomUUID().toString(),
) {
    private val lock = ReentrantLock(true)

    val processInstanceId: String = processInstanceId
    val engineRegistry = ProtectionEngineRegistry(processInstanceId)
    val leaseRegistry = ScannerLeaseRegistry()

    @Volatile
    var lastConfirmedTuple: ProtectionProtocolTuple? = null
        private set

    @Volatile
    var persistenceUncertain: Boolean = false
        private set

    @Volatile
    var stopFenceRaised: Boolean = false
        private set

    /** Intended tuple kept after a false commit so retries do not reread the mutated prefs map. */
    @Volatile
    private var privateAuthorityTuple: ProtectionProtocolTuple? = null

    private var capturedLegacySnapshot: LegacySnapshot? = null

    private val cancelledAttemptIds = linkedSetOf<String>()

    private val listeners = CopyOnWriteArrayList<(ProtectionProtocolTuple) -> Unit>()

    fun addChangeListener(listener: (ProtectionProtocolTuple) -> Unit) {
        listeners.add(listener)
    }

    fun removeChangeListener(listener: (ProtectionProtocolTuple) -> Unit) {
        listeners.remove(listener)
    }

    /** Ensures schema migration / load under the process-wide lock. */
    fun ensureReady(): ProtocolCommitResult {
        return lock.withLock { ensureReadyLocked() }
    }

    fun readConfirmedTuple(): ProtectionProtocolTuple? {
        return lock.withLock {
            if (persistenceUncertain) return@withLock null
            lastConfirmedTuple ?: ensureReadyLocked().let { result ->
                when (result) {
                    is ProtocolCommitResult.Confirmed -> result.tuple
                    else -> null
                }
            }
        }
    }

    fun setBackgroundModePreferred(
        expectedRevision: Long,
        preferred: Boolean,
    ): ProtocolCommitResult {
        return mutate { current ->
            ProtectionProtocolEngine.setBackgroundModePreferred(
                current = current,
                expectedRevision = expectedRevision,
                preferred = preferred,
                stopFenceRaised = stopFenceRaised,
                persistenceUncertain = persistenceUncertain,
            )
        }
    }

    fun beginForegroundIntent(expectedRevision: Long): ProtocolCommitResult {
        return mutate { current ->
            ProtectionProtocolEngine.beginForegroundIntent(
                current = current,
                expectedRevision = expectedRevision,
                stopFenceRaised = stopFenceRaised,
                persistenceUncertain = persistenceUncertain,
            )
        }
    }

    fun allocateBackgroundSession(
        expectedRevision: Long,
        attemptId: String,
        processId: String = processInstanceId,
    ): ProtocolCommitResult {
        return mutate { current ->
            ProtectionProtocolEngine.allocateBackgroundSession(
                current = current,
                expectedRevision = expectedRevision,
                attemptId = attemptId,
                processId = processId,
                stopFenceRaised = stopFenceRaised,
                cancelledAttemptIds = cancelledAttemptIds.toSet(),
                persistenceUncertain = persistenceUncertain,
            )
        }
    }

    fun cancelBackgroundAttempt(attemptId: String): ProtocolCommitResult {
        // Install the attempt fence before waiting on the serial/mutation path.
        lock.withLock { cancelledAttemptIds.add(attemptId) }
        return mutate { current ->
            ProtectionProtocolEngine.cancelBackgroundAttempt(
                current = current,
                attemptId = attemptId,
                stopFenceRaised = stopFenceRaised,
                persistenceUncertain = persistenceUncertain,
            )
        }
    }

    fun switchToForegroundIntent(expectedRevision: Long): ProtocolCommitResult {
        return mutate { current ->
            ProtectionProtocolEngine.switchToForegroundIntent(
                current = current,
                expectedRevision = expectedRevision,
                stopFenceRaised = stopFenceRaised,
                persistenceUncertain = persistenceUncertain,
            )
        }
    }

    fun commitExplicitStop(): ProtocolCommitResult {
        return lock.withLock {
            stopFenceRaised = true
            val ready = ensureReadyLocked()
            val current = when (ready) {
                is ProtocolCommitResult.Confirmed -> ready.tuple
                is ProtocolCommitResult.PersistenceUncertain -> {
                    // Still attempt Stop against private authority when available.
                    ready.intendedTuple ?: ready.lastConfirmedTuple
                }
                is ProtocolCommitResult.Stale -> ready.current
                is ProtocolCommitResult.Rejected -> ready.current
            } ?: privateAuthorityTuple ?: lastConfirmedTuple

            if (current == null) {
                return@withLock ProtocolCommitResult.Rejected(
                    ProtocolRejectReason.GUARD_FAILED,
                    null,
                )
            }

            val intended = ProtectionProtocolEngine.commitExplicitStop(current)
            persistIntendedLocked(intended)
        }
    }

    fun claimTaskIncarnation(
        expectedRevision: Long,
        sessionId: String,
        incarnationId: String,
    ): ProtocolCommitResult {
        return mutate { current ->
            val existing = current.activeTaskIncarnationId
            if (existing != null && existing != incarnationId) {
                // Rebind only when the prior incarnation is gone and holds no lease.
                if (engineRegistry.contains(existing) ||
                    leaseRegistry.current()?.engineIncarnationId == existing
                ) {
                    return@mutate ProtocolMutationOutcome.Rejected(
                        ProtocolRejectReason.GUARD_FAILED,
                        current,
                    )
                }
            }
            ProtectionProtocolEngine.claimTaskIncarnation(
                current = current,
                expectedRevision = expectedRevision,
                sessionId = sessionId,
                incarnationId = incarnationId,
                stopFenceRaised = stopFenceRaised,
                persistenceUncertain = persistenceUncertain,
            )
        }
    }

    fun markTaskScannerReady(
        expectedRevision: Long,
        sessionId: String,
        epoch: Long,
        incarnationId: String,
        leaseId: String,
    ): ProtocolCommitResult {
        return mutate { current ->
            val lease = leaseRegistry.current()
            if (lease == null ||
                lease.leaseId != leaseId ||
                lease.engineIncarnationId != incarnationId ||
                lease.taskSessionId != sessionId ||
                lease.taskEpoch != epoch ||
                lease.ownerKind != ScannerLeaseOwnerKind.BACKGROUND
            ) {
                return@mutate ProtocolMutationOutcome.Rejected(
                    ProtocolRejectReason.GUARD_FAILED,
                    current,
                )
            }
            ProtectionProtocolEngine.markTaskScannerReady(
                current = current,
                expectedRevision = expectedRevision,
                sessionId = sessionId,
                epoch = epoch,
                incarnationId = incarnationId,
                stopFenceRaised = stopFenceRaised,
                persistenceUncertain = persistenceUncertain,
            )
        }
    }

    fun markNativeStartResolved(
        expectedRevision: Long,
        attemptId: String,
    ): ProtocolCommitResult {
        return mutate { current ->
            ProtectionProtocolEngine.markNativeStartResolved(
                current = current,
                expectedRevision = expectedRevision,
                attemptId = attemptId,
                processId = processInstanceId,
                persistenceUncertain = persistenceUncertain,
            )
        }
    }

    fun reapDeadProcessStartLatch(
        expectedRevision: Long,
        processId: String,
    ): ProtocolCommitResult {
        return mutate { current ->
            ProtectionProtocolEngine.reapDeadProcessStartLatch(
                current = current,
                expectedRevision = expectedRevision,
                currentProcessId = processId,
                persistenceUncertain = persistenceUncertain,
            )
        }
    }

    fun finaliseSession(
        expectedRevision: Long,
        sessionId: String,
    ): ProtocolCommitResult {
        return mutate { current ->
            ProtectionProtocolEngine.finaliseSession(
                current = current,
                expectedRevision = expectedRevision,
                sessionId = sessionId,
                persistenceUncertain = persistenceUncertain,
            )
        }
    }

    fun acquireForegroundLease(
        engineIncarnationId: String,
        rollbackForAttemptId: String? = null,
    ): ScannerLeaseAcquireResult {
        return lock.withLock {
            val tuple = lastConfirmedTuple
            val guardOk = if (rollbackForAttemptId != null) {
                foregroundRollbackGuardOk(tuple, rollbackForAttemptId)
            } else {
                foregroundDirectGuardOk(tuple)
            }

            leaseRegistry.tryAcquire(
                ownerKind = ScannerLeaseOwnerKind.FOREGROUND,
                engineIncarnationId = engineIncarnationId,
                stopFenceRaised = stopFenceRaised,
                persistenceUncertain = persistenceUncertain,
                enginePresent = engineRegistry.contains(engineIncarnationId),
                additionalGuardOk = guardOk,
            )
        }
    }

    fun acquireTaskLease(
        engineIncarnationId: String,
        sessionId: String,
        epoch: Long,
    ): ScannerLeaseAcquireResult {
        return lock.withLock {
            val tuple = lastConfirmedTuple
            val guardOk = tuple != null &&
                tuple.backgroundRuntimeEnabled &&
                !tuple.explicitlyStopped &&
                tuple.activeTaskSessionId == sessionId &&
                tuple.activeTaskEpoch == epoch &&
                (tuple.activeTaskIncarnationId == null ||
                    tuple.activeTaskIncarnationId == engineIncarnationId)

            leaseRegistry.tryAcquire(
                ownerKind = ScannerLeaseOwnerKind.BACKGROUND,
                engineIncarnationId = engineIncarnationId,
                taskSessionId = sessionId,
                taskEpoch = epoch,
                stopFenceRaised = stopFenceRaised,
                persistenceUncertain = persistenceUncertain,
                enginePresent = engineRegistry.contains(engineIncarnationId),
                additionalGuardOk = guardOk,
            )
        }
    }

    fun markLeaseActive(leaseId: String): Boolean {
        return lock.withLock { leaseRegistry.markActive(leaseId) }
    }

    fun releaseLease(leaseId: String): Boolean {
        return lock.withLock { leaseRegistry.release(leaseId) }
    }

    fun releaseLeaseForEngine(engineIncarnationId: String): ScannerLease? {
        return lock.withLock {
            leaseRegistry.releaseIfOwnedBy(engineIncarnationId)
        }
    }

    fun unregisterEngine(engineIncarnationId: String) {
        lock.withLock {
            leaseRegistry.releaseIfOwnedBy(engineIncarnationId)
            engineRegistry.unregister(engineIncarnationId)
        }
    }

    private fun foregroundDirectGuardOk(tuple: ProtectionProtocolTuple?): Boolean {
        return tuple != null &&
            tuple.protectionEnabled &&
            !tuple.explicitlyStopped &&
            !tuple.backgroundRuntimeEnabled &&
            tuple.activeTaskSessionId == null &&
            !engineRegistry.hasTaskEngine() &&
            leaseRegistry.current() == null
    }

    private fun foregroundRollbackGuardOk(
        tuple: ProtectionProtocolTuple?,
        rollbackForAttemptId: String,
    ): Boolean {
        return tuple != null &&
            tuple.protectionEnabled &&
            !tuple.explicitlyStopped &&
            !tuple.backgroundRuntimeEnabled &&
            tuple.taskPhase == TaskPhase.CANCELLING &&
            tuple.activeTaskSessionId != null &&
            tuple.activeStartAttemptId == rollbackForAttemptId &&
            rollbackForAttemptId in cancelledAttemptIds &&
            !engineRegistry.hasTaskEngine() &&
            leaseRegistry.current() == null
    }

    private fun mutate(
        block: (ProtectionProtocolTuple) -> ProtocolMutationOutcome,
    ): ProtocolCommitResult {
        return lock.withLock {
            val ready = ensureReadyLocked()
            if (ready is ProtocolCommitResult.PersistenceUncertain) {
                return@withLock ProtocolCommitResult.Rejected(
                    ProtocolRejectReason.PERSISTENCE_UNCERTAIN,
                    ready.lastConfirmedTuple,
                )
            }
            val current = lastConfirmedTuple
                ?: return@withLock ProtocolCommitResult.Rejected(
                    ProtocolRejectReason.GUARD_FAILED,
                    null,
                )

            when (val outcome = block(current)) {
                is ProtocolMutationOutcome.Accepted -> {
                    cancelledAttemptIds.addAll(outcome.raiseAttemptFenceIds)
                    if (outcome.tuple.revision == current.revision) {
                        // Fence-only / no-op acceptance — nothing to persist.
                        return@withLock ProtocolCommitResult.Confirmed(current)
                    }
                    val persisted = persistIntendedLocked(outcome.tuple)
                    if (persisted is ProtocolCommitResult.Confirmed && outcome.clearStopFence) {
                        stopFenceRaised = false
                    }
                    persisted
                }
                is ProtocolMutationOutcome.Stale ->
                    ProtocolCommitResult.Stale(outcome.current)
                is ProtocolMutationOutcome.Rejected ->
                    ProtocolCommitResult.Rejected(outcome.reason, outcome.current)
            }
        }
    }

    private fun ensureReadyLocked(): ProtocolCommitResult {
        if (persistenceUncertain && privateAuthorityTuple != null) {
            // Same-process retry from private authority without rereading mutated prefs.
            return persistIntendedLocked(privateAuthorityTuple!!)
        }

        lastConfirmedTuple?.let {
            return forceBackgroundDefaultOnLocked(it)
        }

        if (persistence.hasSchemaMarker()) {
            val loaded = persistence.readTuple()
            if (loaded != null) {
                lastConfirmedTuple = loaded
                privateAuthorityTuple = loaded
                return forceBackgroundDefaultOnLocked(loaded)
            }
        }

        val legacy = capturedLegacySnapshot ?: persistence.readLegacySnapshot().also {
            capturedLegacySnapshot = it
        }
        val migrated = ProtectionProtocolEngine.migrateFromLegacy(legacy)
        privateAuthorityTuple = migrated
        val persisted = persistIntendedLocked(migrated)
        if (persisted is ProtocolCommitResult.Confirmed) {
            persistence.markForcedBackgroundDefaultOn()
        }
        return persisted
    }

    private fun forceBackgroundDefaultOnLocked(
        current: ProtectionProtocolTuple,
    ): ProtocolCommitResult {
        if (persistence.hasForcedBackgroundDefaultOn()) {
            return ProtocolCommitResult.Confirmed(current)
        }
        if (current.backgroundModePreferred) {
            persistence.markForcedBackgroundDefaultOn()
            return ProtocolCommitResult.Confirmed(current)
        }
        val forced = current.copy(
            revision = current.revision + 1,
            backgroundModePreferred = true,
        )
        privateAuthorityTuple = forced
        val persisted = persistIntendedLocked(forced)
        if (persisted is ProtocolCommitResult.Confirmed) {
            persistence.markForcedBackgroundDefaultOn()
        }
        return persisted
    }

    private fun persistIntendedLocked(intended: ProtectionProtocolTuple): ProtocolCommitResult {
        privateAuthorityTuple = intended
        val ok = commitFn(intended)
        return if (ok) {
            lastConfirmedTuple = intended
            persistenceUncertain = false
            notifyListeners(intended)
            ProtocolCommitResult.Confirmed(intended)
        } else {
            persistenceUncertain = true
            ProtocolCommitResult.PersistenceUncertain(
                intendedTuple = intended,
                lastConfirmedTuple = lastConfirmedTuple,
            )
        }
    }

    private fun notifyListeners(tuple: ProtectionProtocolTuple) {
        for (listener in listeners) {
            try {
                listener(tuple)
            } catch (_: RuntimeException) {
                // Best-effort revision notifications must not break the repository.
            }
        }
    }
}
