package app.unrecorded.unrecorded_mobile.protocol

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ProtectionProtocolEngineTest {

    // --- 8 legacy migration combinations ---

    @Test
    fun migrate_allEightLegacyCombos() {
        val combos = listOf(
            Triple(false, false, false),
            Triple(false, false, true),
            Triple(false, true, false),
            Triple(false, true, true),
            Triple(true, false, false),
            Triple(true, false, true),
            Triple(true, true, false),
            Triple(true, true, true),
        )
        assertEquals(8, combos.size)

        for ((protection, background, explicitStop) in combos) {
            val tuple = ProtectionProtocolEngine.migrateFromLegacy(
                LegacySnapshot(protection, background, explicitStop),
            )
            assertEquals(1, tuple.schemaVersion)
            assertEquals(1L, tuple.revision)
            assertEquals(1L, tuple.nextTaskGeneration)
            assertFalse(tuple.backgroundRuntimeEnabled)
            assertNull(tuple.activeTaskSessionId)
            assertNull(tuple.activeTaskEpoch)
            assertNull(tuple.activeTaskIncarnationId)
            assertNull(tuple.activeStartAttemptId)
            assertNull(tuple.activeStartProcessId)
            assertEquals(TaskPhase.NONE, tuple.taskPhase)
            assertFalse(tuple.nativeStartUnresolved)

            if (explicitStop) {
                assertFalse(
                    "explicit Stop must dominate for $protection/$background/$explicitStop",
                    tuple.protectionEnabled,
                )
                assertTrue(tuple.backgroundModePreferred)
                assertTrue(tuple.explicitlyStopped)
            } else {
                assertEquals(protection || background, tuple.protectionEnabled)
                assertTrue(tuple.backgroundModePreferred)
                assertFalse(tuple.explicitlyStopped)
            }
        }
    }

    @Test
    fun migrate_backgroundTrueWithoutStop_preservesPreferredAndOverallIntent() {
        val tuple = ProtectionProtocolEngine.migrateFromLegacy(
            LegacySnapshot(
                protectionEnabled = false,
                backgroundProtectionEnabled = true,
                explicitlyStopped = false,
            ),
        )
        assertTrue(tuple.protectionEnabled)
        assertTrue(tuple.backgroundModePreferred)
        assertFalse(tuple.backgroundRuntimeEnabled)
    }

    // --- Stop fence ---

    @Test
    fun stopFence_rejectsEnableWhenStopCommitFailed() {
        val current = ProtectionProtocolEngine.migrateFromLegacy(
            LegacySnapshot(true, false, false),
        )
        assertTrue(current.protectionEnabled)
        assertFalse(current.explicitlyStopped)

        val outcome = ProtectionProtocolEngine.beginForegroundIntent(
            current = current,
            expectedRevision = current.revision,
            stopFenceRaised = true,
            persistenceUncertain = false,
        )
        assertTrue(outcome is ProtocolMutationOutcome.Rejected)
        assertEquals(
            ProtocolRejectReason.STOP_FENCE,
            (outcome as ProtocolMutationOutcome.Rejected).reason,
        )
    }

    @Test
    fun stopFence_rejectsAllocateAndAllowsEnableOnlyAfterConfirmedStop() {
        val running = ProtectionProtocolEngine.migrateFromLegacy(
            LegacySnapshot(true, true, false),
        )
        val allocateRejected = ProtectionProtocolEngine.allocateBackgroundSession(
            current = running,
            expectedRevision = running.revision,
            attemptId = "a1",
            processId = "proc",
            stopFenceRaised = true,
            cancelledAttemptIds = emptySet(),
            persistenceUncertain = false,
        )
        assertEquals(
            ProtocolRejectReason.STOP_FENCE,
            (allocateRejected as ProtocolMutationOutcome.Rejected).reason,
        )

        val stopped = ProtectionProtocolEngine.commitExplicitStop(running)
        assertTrue(stopped.explicitlyStopped)
        assertFalse(stopped.protectionEnabled)
        assertTrue(stopped.backgroundModePreferred)

        val enable = ProtectionProtocolEngine.beginForegroundIntent(
            current = stopped,
            expectedRevision = stopped.revision,
            stopFenceRaised = true,
            persistenceUncertain = false,
        )
        assertTrue(enable is ProtocolMutationOutcome.Accepted)
        val accepted = enable as ProtocolMutationOutcome.Accepted
        assertTrue(accepted.clearStopFence)
        assertTrue(accepted.tuple.protectionEnabled)
        assertFalse(accepted.tuple.explicitlyStopped)
    }

    @Test
    fun stopFence_preferenceChangeStillAllowed() {
        val stopped = ProtectionProtocolEngine.commitExplicitStop(
            ProtectionProtocolEngine.migrateFromLegacy(LegacySnapshot(true, true, false)),
        )
        val outcome = ProtectionProtocolEngine.setBackgroundModePreferred(
            current = stopped,
            expectedRevision = stopped.revision,
            preferred = false,
            stopFenceRaised = true,
            persistenceUncertain = false,
        )
        assertTrue(outcome is ProtocolMutationOutcome.Accepted)
        assertFalse((outcome as ProtocolMutationOutcome.Accepted).tuple.backgroundModePreferred)
    }

    // --- Stale revision ---

    @Test
    fun staleRevision_rejectedWithoutMutation() {
        val current = ProtectionProtocolEngine.migrateFromLegacy(
            LegacySnapshot(false, false, false),
        )
        val outcome = ProtectionProtocolEngine.setBackgroundModePreferred(
            current = current,
            expectedRevision = current.revision - 1,
            preferred = true,
            stopFenceRaised = false,
            persistenceUncertain = false,
        )
        assertTrue(outcome is ProtocolMutationOutcome.Stale)
        assertEquals(current, (outcome as ProtocolMutationOutcome.Stale).current)
    }

    @Test
    fun acceptedMutation_advancesRevisionExactlyOnce() {
        val current = ProtectionProtocolEngine.migrateFromLegacy(
            LegacySnapshot(false, false, false),
        )
        val outcome = ProtectionProtocolEngine.beginForegroundIntent(
            current = current,
            expectedRevision = current.revision,
            stopFenceRaised = false,
            persistenceUncertain = false,
        )
        val accepted = outcome as ProtocolMutationOutcome.Accepted
        assertEquals(current.revision + 1, accepted.tuple.revision)
    }

    // --- Commit false uncertainty ---

    @Test
    fun commitFalse_marksPersistenceUncertainAndBlocksLease() {
        val failing = InMemoryProtectionProtocolPersistence()
        failing.commitSucceeds = false
        val repo = ProtectionProtocolRepository(
            persistence = failing,
            processInstanceId = "proc-test",
        )

        val result = repo.ensureReady()
        assertTrue(result is ProtocolCommitResult.PersistenceUncertain)
        assertTrue(repo.persistenceUncertain)
        assertNull(repo.readConfirmedTuple())

        val incarnation = repo.engineRegistry.register(EngineKind.MAIN)
        val lease = repo.acquireForegroundLease(incarnation)
        assertTrue(lease is ScannerLeaseAcquireResult.Rejected)
        assertEquals(
            ScannerLeaseRejectReason.PERSISTENCE_UNCERTAIN,
            (lease as ScannerLeaseAcquireResult.Rejected).reason,
        )
    }

    @Test
    fun commitFalse_stopFenceBlocksLeaseEvenWhenLastConfirmedStillEnabled() {
        val store = InMemoryProtectionProtocolPersistence()
        val repo = ProtectionProtocolRepository(
            persistence = store,
            processInstanceId = "proc-stop",
        )
        assertTrue(repo.ensureReady() is ProtocolCommitResult.Confirmed)
        val enabled = repo.beginForegroundIntent(expectedRevision = 1L)
        assertTrue(enabled is ProtocolCommitResult.Confirmed)

        store.commitSucceeds = false
        val stop = repo.commitExplicitStop()
        assertTrue(stop is ProtocolCommitResult.PersistenceUncertain)
        assertTrue(repo.stopFenceRaised)
        assertTrue(repo.persistenceUncertain)

        val incarnation = repo.engineRegistry.register(EngineKind.MAIN)
        val lease = repo.acquireForegroundLease(incarnation)
        assertTrue(lease is ScannerLeaseAcquireResult.Rejected)
        // Persistence uncertainty is checked first; either fence or uncertainty is correct reject.
        val reason = (lease as ScannerLeaseAcquireResult.Rejected).reason
        assertTrue(
            reason == ScannerLeaseRejectReason.PERSISTENCE_UNCERTAIN ||
                reason == ScannerLeaseRejectReason.STOP_FENCE,
        )
    }

    @Test
    fun commitFalse_sameProcessRetryFromPrivateAuthorityWithoutReread() {
        val store = InMemoryProtectionProtocolPersistence()
        store.commitSucceeds = false
        val repo = ProtectionProtocolRepository(
            persistence = store,
            processInstanceId = "proc-retry",
        )
        val first = repo.ensureReady()
        assertTrue(first is ProtocolCommitResult.PersistenceUncertain)

        // Mutate the in-memory map as Android would after a false commit(), while private
        // authority retains the intended migrated tuple.
        store.corruptInMemoryMap()

        store.commitSucceeds = true
        val retry = repo.ensureReady()
        assertTrue(retry is ProtocolCommitResult.Confirmed)
        val tuple = (retry as ProtocolCommitResult.Confirmed).tuple
        assertEquals(1, tuple.schemaVersion)
        assertEquals(1L, tuple.revision)
        assertFalse(repo.persistenceUncertain)
        // Corrupted map values must not have been used as the retry source.
        assertEquals(tuple, store.readTuple())
    }

    @Test
    fun persistenceUncertain_rejectsEngineMutations() {
        val current = ProtectionProtocolEngine.migrateFromLegacy(
            LegacySnapshot(true, false, false),
        )
        val outcome = ProtectionProtocolEngine.beginForegroundIntent(
            current = current,
            expectedRevision = current.revision,
            stopFenceRaised = false,
            persistenceUncertain = true,
        )
        assertEquals(
            ProtocolRejectReason.PERSISTENCE_UNCERTAIN,
            (outcome as ProtocolMutationOutcome.Rejected).reason,
        )
    }

    // --- Lease contention ---

    @Test
    fun leaseContention_secondAcquireRejected() {
        val registry = ScannerLeaseRegistry()
        val first = registry.tryAcquire(
            ownerKind = ScannerLeaseOwnerKind.FOREGROUND,
            engineIncarnationId = "proc:1",
            stopFenceRaised = false,
            persistenceUncertain = false,
            enginePresent = true,
        )
        assertTrue(first is ScannerLeaseAcquireResult.Acquired)

        val second = registry.tryAcquire(
            ownerKind = ScannerLeaseOwnerKind.BACKGROUND,
            engineIncarnationId = "proc:2",
            taskSessionId = "task-1",
            taskEpoch = 2L,
            stopFenceRaised = false,
            persistenceUncertain = false,
            enginePresent = true,
        )
        assertTrue(second is ScannerLeaseAcquireResult.Rejected)
        assertEquals(
            ScannerLeaseRejectReason.LEASE_HELD,
            (second as ScannerLeaseAcquireResult.Rejected).reason,
        )

        val leaseId = (first as ScannerLeaseAcquireResult.Acquired).lease.leaseId
        assertTrue(registry.release(leaseId))
        val third = registry.tryAcquire(
            ownerKind = ScannerLeaseOwnerKind.BACKGROUND,
            engineIncarnationId = "proc:2",
            taskSessionId = "task-1",
            taskEpoch = 2L,
            stopFenceRaised = false,
            persistenceUncertain = false,
            enginePresent = true,
        )
        assertTrue(third is ScannerLeaseAcquireResult.Acquired)
    }

    @Test
    fun lease_stopFenceAndMissingEngineReject() {
        val registry = ScannerLeaseRegistry()
        val fenced = registry.tryAcquire(
            ownerKind = ScannerLeaseOwnerKind.FOREGROUND,
            engineIncarnationId = "proc:1",
            stopFenceRaised = true,
            persistenceUncertain = false,
            enginePresent = true,
        )
        assertEquals(
            ScannerLeaseRejectReason.STOP_FENCE,
            (fenced as ScannerLeaseAcquireResult.Rejected).reason,
        )

        val absent = registry.tryAcquire(
            ownerKind = ScannerLeaseOwnerKind.FOREGROUND,
            engineIncarnationId = "proc:1",
            stopFenceRaised = false,
            persistenceUncertain = false,
            enginePresent = false,
        )
        assertEquals(
            ScannerLeaseRejectReason.ENGINE_ABSENT,
            (absent as ScannerLeaseAcquireResult.Rejected).reason,
        )
    }

    @Test
    fun attemptFence_rejectsLateAllocation() {
        val current = ProtectionProtocolEngine.beginForegroundIntent(
            current = ProtectionProtocolEngine.migrateFromLegacy(
                LegacySnapshot(false, false, false),
            ),
            expectedRevision = 1L,
            stopFenceRaised = false,
            persistenceUncertain = false,
        ).let { (it as ProtocolMutationOutcome.Accepted).tuple }

        val cancelled = ProtectionProtocolEngine.cancelBackgroundAttempt(
            current = current,
            attemptId = "attempt-x",
            stopFenceRaised = false,
            persistenceUncertain = false,
        )
        assertTrue(cancelled is ProtocolMutationOutcome.Accepted)
        assertEquals(
            setOf("attempt-x"),
            (cancelled as ProtocolMutationOutcome.Accepted).raiseAttemptFenceIds,
        )

        val allocate = ProtectionProtocolEngine.allocateBackgroundSession(
            current = current,
            expectedRevision = current.revision,
            attemptId = "attempt-x",
            processId = "proc",
            stopFenceRaised = false,
            cancelledAttemptIds = setOf("attempt-x"),
            persistenceUncertain = false,
        )
        assertEquals(
            ProtocolRejectReason.ATTEMPT_FENCE,
            (allocate as ProtocolMutationOutcome.Rejected).reason,
        )
    }

    @Test
    fun allocate_setsSessionRuntimePhaseAndNativeStartLatch() {
        val enabled = ProtectionProtocolEngine.beginForegroundIntent(
            current = ProtectionProtocolEngine.migrateFromLegacy(
                LegacySnapshot(false, true, false),
            ),
            expectedRevision = 1L,
            stopFenceRaised = false,
            persistenceUncertain = false,
        ).let { (it as ProtocolMutationOutcome.Accepted).tuple }

        val allocate = ProtectionProtocolEngine.allocateBackgroundSession(
            current = enabled,
            expectedRevision = enabled.revision,
            attemptId = "attempt-1",
            processId = "proc-a",
            stopFenceRaised = false,
            cancelledAttemptIds = emptySet(),
            persistenceUncertain = false,
        )
        val tuple = (allocate as ProtocolMutationOutcome.Accepted).tuple
        assertEquals("task-1", tuple.activeTaskSessionId)
        assertEquals(enabled.revision + 1, tuple.activeTaskEpoch)
        assertEquals(2L, tuple.nextTaskGeneration)
        assertTrue(tuple.backgroundRuntimeEnabled)
        assertEquals(TaskPhase.ALLOCATED, tuple.taskPhase)
        assertTrue(tuple.nativeStartUnresolved)
        assertEquals("attempt-1", tuple.activeStartAttemptId)
        assertEquals("proc-a", tuple.activeStartProcessId)
        assertNull(tuple.activeTaskIncarnationId)
    }

    @Test
    fun cancel_disablesRuntimeAndRetainsSessionTombstone() {
        val allocated = allocatedTuple()
        val cancel = ProtectionProtocolEngine.cancelBackgroundAttempt(
            current = allocated,
            attemptId = "attempt-1",
            stopFenceRaised = false,
            persistenceUncertain = false,
        )
        val tuple = (cancel as ProtocolMutationOutcome.Accepted).tuple
        assertFalse(tuple.backgroundRuntimeEnabled)
        assertEquals(TaskPhase.CANCELLING, tuple.taskPhase)
        assertEquals("task-1", tuple.activeTaskSessionId)
        assertEquals("attempt-1", tuple.activeStartAttemptId)
        assertTrue(tuple.protectionEnabled)
        assertEquals(setOf("attempt-1"), cancel.raiseAttemptFenceIds)
    }

    @Test
    fun switchToForegroundIntent_clearsPreferredAndRuntime() {
        val allocated = allocatedTuple()
        val switched = ProtectionProtocolEngine.switchToForegroundIntent(
            current = allocated,
            expectedRevision = allocated.revision,
            stopFenceRaised = false,
            persistenceUncertain = false,
        )
        val tuple = (switched as ProtocolMutationOutcome.Accepted).tuple
        assertFalse(tuple.backgroundModePreferred)
        assertFalse(tuple.backgroundRuntimeEnabled)
        assertEquals(TaskPhase.CANCELLING, tuple.taskPhase)
        assertTrue(tuple.protectionEnabled)
        assertEquals("task-1", tuple.activeTaskSessionId)
    }

    @Test
    fun markReady_andFinalise_happyPath() {
        val allocated = allocatedTuple()
        val claimed = ProtectionProtocolEngine.claimTaskIncarnation(
            current = allocated,
            expectedRevision = allocated.revision,
            sessionId = "task-1",
            incarnationId = "proc:1",
            stopFenceRaised = false,
            persistenceUncertain = false,
        ).let { (it as ProtocolMutationOutcome.Accepted).tuple }

        val ready = ProtectionProtocolEngine.markTaskScannerReady(
            current = claimed,
            expectedRevision = claimed.revision,
            sessionId = "task-1",
            epoch = allocated.activeTaskEpoch!!,
            incarnationId = "proc:1",
            stopFenceRaised = false,
            persistenceUncertain = false,
        )
        val readyTuple = (ready as ProtocolMutationOutcome.Accepted).tuple
        assertEquals(TaskPhase.SCANNER_READY, readyTuple.taskPhase)

        val resolved = ProtectionProtocolEngine.markNativeStartResolved(
            current = readyTuple,
            expectedRevision = readyTuple.revision,
            attemptId = "attempt-1",
            processId = "proc-a",
            persistenceUncertain = false,
        ).let { (it as ProtocolMutationOutcome.Accepted).tuple }
        assertFalse(resolved.nativeStartUnresolved)

        val finalised = ProtectionProtocolEngine.finaliseSession(
            current = resolved,
            expectedRevision = resolved.revision,
            sessionId = "task-1",
            persistenceUncertain = false,
        )
        val cleared = (finalised as ProtocolMutationOutcome.Accepted).tuple
        assertNull(cleared.activeTaskSessionId)
        assertNull(cleared.activeTaskEpoch)
        assertFalse(cleared.backgroundRuntimeEnabled)
        assertEquals(TaskPhase.NONE, cleared.taskPhase)
        assertTrue(cleared.protectionEnabled)
        assertEquals(2L, cleared.nextTaskGeneration)
    }

    @Test
    fun staleRevision_rejectsAllocateClaimReadyAndFinalise() {
        val allocated = allocatedTuple()
        val staleRev = allocated.revision - 1

        assertTrue(
            ProtectionProtocolEngine.allocateBackgroundSession(
                current = allocated,
                expectedRevision = staleRev,
                attemptId = "other",
                processId = "proc",
                stopFenceRaised = false,
                cancelledAttemptIds = emptySet(),
                persistenceUncertain = false,
            ) is ProtocolMutationOutcome.Stale,
        )
        assertTrue(
            ProtectionProtocolEngine.claimTaskIncarnation(
                current = allocated,
                expectedRevision = staleRev,
                sessionId = "task-1",
                incarnationId = "proc:1",
                stopFenceRaised = false,
                persistenceUncertain = false,
            ) is ProtocolMutationOutcome.Stale,
        )
        assertTrue(
            ProtectionProtocolEngine.markTaskScannerReady(
                current = allocated,
                expectedRevision = staleRev,
                sessionId = "task-1",
                epoch = allocated.activeTaskEpoch!!,
                incarnationId = "proc:1",
                stopFenceRaised = false,
                persistenceUncertain = false,
            ) is ProtocolMutationOutcome.Stale,
        )
        assertTrue(
            ProtectionProtocolEngine.finaliseSession(
                current = allocated,
                expectedRevision = staleRev,
                sessionId = "task-1",
                persistenceUncertain = false,
            ) is ProtocolMutationOutcome.Stale,
        )
        assertTrue(
            ProtectionProtocolEngine.switchToForegroundIntent(
                current = allocated,
                expectedRevision = staleRev,
                stopFenceRaised = false,
                persistenceUncertain = false,
            ) is ProtocolMutationOutcome.Stale,
        )
        assertTrue(
            ProtectionProtocolEngine.reapDeadProcessStartLatch(
                current = allocated,
                expectedRevision = staleRev,
                currentProcessId = "other-proc",
                persistenceUncertain = false,
            ) is ProtocolMutationOutcome.Stale,
        )
    }

    @Test
    fun reapDeadProcessStartLatch_clearsOnlyForeignProcessLatch() {
        val allocated = allocatedTuple()
        val sameProcess = ProtectionProtocolEngine.reapDeadProcessStartLatch(
            current = allocated,
            expectedRevision = allocated.revision,
            currentProcessId = "proc-a",
            persistenceUncertain = false,
        )
        assertEquals(
            ProtocolRejectReason.GUARD_FAILED,
            (sameProcess as ProtocolMutationOutcome.Rejected).reason,
        )

        val foreign = ProtectionProtocolEngine.reapDeadProcessStartLatch(
            current = allocated,
            expectedRevision = allocated.revision,
            currentProcessId = "proc-b",
            persistenceUncertain = false,
        )
        val tuple = (foreign as ProtocolMutationOutcome.Accepted).tuple
        assertFalse(tuple.nativeStartUnresolved)
        assertEquals("task-1", tuple.activeTaskSessionId)
    }

    @Test
    fun stopFence_rejectsTaskLeaseAcquisition() {
        val store = InMemoryProtectionProtocolPersistence()
        val repo = ProtectionProtocolRepository(
            persistence = store,
            processInstanceId = "proc-lease",
        )
        assertTrue(repo.ensureReady() is ProtocolCommitResult.Confirmed)
        val enabled = repo.beginForegroundIntent(expectedRevision = 1L)
        assertTrue(enabled is ProtocolCommitResult.Confirmed)
        val enabledTuple = (enabled as ProtocolCommitResult.Confirmed).tuple

        val allocate = repo.allocateBackgroundSession(
            expectedRevision = enabledTuple.revision,
            attemptId = "a1",
            processId = "proc-lease",
        )
        assertTrue(allocate is ProtocolCommitResult.Confirmed)
        val allocated = (allocate as ProtocolCommitResult.Confirmed).tuple

        val taskIncarnation = repo.engineRegistry.register(EngineKind.TASK)
        val claimed = repo.claimTaskIncarnation(
            expectedRevision = allocated.revision,
            sessionId = allocated.activeTaskSessionId!!,
            incarnationId = taskIncarnation,
        )
        assertTrue(claimed is ProtocolCommitResult.Confirmed)

        store.commitSucceeds = false
        val stop = repo.commitExplicitStop()
        assertTrue(stop is ProtocolCommitResult.PersistenceUncertain)
        assertTrue(repo.stopFenceRaised)

        val lease = repo.acquireTaskLease(
            engineIncarnationId = taskIncarnation,
            sessionId = allocated.activeTaskSessionId!!,
            epoch = allocated.activeTaskEpoch!!,
        )
        assertTrue(lease is ScannerLeaseAcquireResult.Rejected)
        val reason = (lease as ScannerLeaseAcquireResult.Rejected).reason
        assertTrue(
            reason == ScannerLeaseRejectReason.STOP_FENCE ||
                reason == ScannerLeaseRejectReason.PERSISTENCE_UNCERTAIN,
        )
    }

    @Test
    fun repository_markReadyFinaliseAndRollbackForegroundLease() {
        val store = InMemoryProtectionProtocolPersistence()
        val repo = ProtectionProtocolRepository(
            persistence = store,
            processInstanceId = "proc-flow",
        )
        assertTrue(repo.ensureReady() is ProtocolCommitResult.Confirmed)
        val enabled = (repo.beginForegroundIntent(1L) as ProtocolCommitResult.Confirmed).tuple
        val allocated = (repo.allocateBackgroundSession(
            expectedRevision = enabled.revision,
            attemptId = "roll-1",
            processId = "proc-flow",
        ) as ProtocolCommitResult.Confirmed).tuple

        val taskIncarnation = repo.engineRegistry.register(EngineKind.TASK)
        val claimed = (repo.claimTaskIncarnation(
            expectedRevision = allocated.revision,
            sessionId = allocated.activeTaskSessionId!!,
            incarnationId = taskIncarnation,
        ) as ProtocolCommitResult.Confirmed).tuple

        val lease = repo.acquireTaskLease(
            engineIncarnationId = taskIncarnation,
            sessionId = claimed.activeTaskSessionId!!,
            epoch = claimed.activeTaskEpoch!!,
        )
        assertTrue(lease is ScannerLeaseAcquireResult.Acquired)
        val leaseId = (lease as ScannerLeaseAcquireResult.Acquired).lease.leaseId
        assertTrue(repo.markLeaseActive(leaseId))

        val ready = repo.markTaskScannerReady(
            expectedRevision = claimed.revision,
            sessionId = claimed.activeTaskSessionId!!,
            epoch = claimed.activeTaskEpoch!!,
            incarnationId = taskIncarnation,
            leaseId = leaseId,
        )
        assertTrue(ready is ProtocolCommitResult.Confirmed)
        assertEquals(
            TaskPhase.SCANNER_READY,
            (ready as ProtocolCommitResult.Confirmed).tuple.taskPhase,
        )

        assertTrue(repo.releaseLease(leaseId))
        repo.engineRegistry.unregister(taskIncarnation)

        val cancelled = repo.cancelBackgroundAttempt("roll-1")
        assertTrue(cancelled is ProtocolCommitResult.Confirmed)
        val tombstone = (cancelled as ProtocolCommitResult.Confirmed).tuple
        assertEquals(TaskPhase.CANCELLING, tombstone.taskPhase)

        val mainIncarnation = repo.engineRegistry.register(EngineKind.MAIN)
        val directRejected = repo.acquireForegroundLease(mainIncarnation)
        assertTrue(directRejected is ScannerLeaseAcquireResult.Rejected)

        val rollback = repo.acquireForegroundLease(
            engineIncarnationId = mainIncarnation,
            rollbackForAttemptId = "roll-1",
        )
        assertTrue(rollback is ScannerLeaseAcquireResult.Acquired)

        val resolved = repo.markNativeStartResolved(
            expectedRevision = tombstone.revision,
            attemptId = "roll-1",
        )
        assertTrue(resolved is ProtocolCommitResult.Confirmed)

        val finalised = repo.finaliseSession(
            expectedRevision = (resolved as ProtocolCommitResult.Confirmed).tuple.revision,
            sessionId = tombstone.activeTaskSessionId!!,
        )
        assertTrue(finalised is ProtocolCommitResult.Confirmed)
        assertNull((finalised as ProtocolCommitResult.Confirmed).tuple.activeTaskSessionId)
    }

    @Test
    fun engineRegistry_assignsUniqueProcessScopedIncarnations() {
        val registry = ProtectionEngineRegistry("abc")
        val main = registry.register(EngineKind.MAIN)
        val task = registry.register(EngineKind.TASK)
        assertTrue(main.startsWith("abc:"))
        assertTrue(task.startsWith("abc:"))
        assertTrue(main != task)
        assertTrue(registry.hasMainEngine())
        assertTrue(registry.hasTaskEngine())
        registry.unregister(task)
        assertFalse(registry.hasTaskEngine())
    }

    private fun allocatedTuple(): ProtectionProtocolTuple {
        val enabled = ProtectionProtocolEngine.beginForegroundIntent(
            current = ProtectionProtocolEngine.migrateFromLegacy(
                LegacySnapshot(false, true, false),
            ),
            expectedRevision = 1L,
            stopFenceRaised = false,
            persistenceUncertain = false,
        ).let { (it as ProtocolMutationOutcome.Accepted).tuple }
        return ProtectionProtocolEngine.allocateBackgroundSession(
            current = enabled,
            expectedRevision = enabled.revision,
            attemptId = "attempt-1",
            processId = "proc-a",
            stopFenceRaised = false,
            cancelledAttemptIds = emptySet(),
            persistenceUncertain = false,
        ).let { (it as ProtocolMutationOutcome.Accepted).tuple }
    }
}

/** In-memory SharedPreferences stand-in for repository unit tests (no Android runtime). */
private class InMemoryProtectionProtocolPersistence : ProtectionProtocolPersistence {
    private val map = linkedMapOf<String, Any?>()
    var commitSucceeds: Boolean = true

    override fun hasSchemaMarker(): Boolean =
        map.containsKey(AndroidProtectionProtocolPersistence.KEY_SCHEMA_VERSION)

    override fun readLegacySnapshot(): LegacySnapshot {
        return LegacySnapshot(
            protectionEnabled = map[AndroidProtectionProtocolPersistence.KEY_PROTECTION_ENABLED] as? Boolean ?: false,
            backgroundProtectionEnabled =
                map[AndroidProtectionProtocolPersistence.KEY_LEGACY_BACKGROUND_PROTECTION_ENABLED] as? Boolean
                    ?: false,
            explicitlyStopped =
                map[AndroidProtectionProtocolPersistence.KEY_LEGACY_BACKGROUND_EXPLICITLY_STOPPED] as? Boolean
                    ?: false,
        )
    }

    override fun readTuple(): ProtectionProtocolTuple? {
        if (!hasSchemaMarker()) return null
        val schemaVersion =
            (map[AndroidProtectionProtocolPersistence.KEY_SCHEMA_VERSION] as Long).toInt()
        return ProtectionProtocolTuple(
            schemaVersion = schemaVersion,
            revision = map[AndroidProtectionProtocolPersistence.KEY_REVISION] as Long,
            backgroundModePreferred =
                map[AndroidProtectionProtocolPersistence.KEY_BACKGROUND_MODE_PREFERRED] as Boolean,
            protectionEnabled =
                map[AndroidProtectionProtocolPersistence.KEY_PROTECTION_ENABLED] as Boolean,
            backgroundRuntimeEnabled =
                map[AndroidProtectionProtocolPersistence.KEY_BACKGROUND_RUNTIME_ENABLED] as Boolean,
            explicitlyStopped =
                map[AndroidProtectionProtocolPersistence.KEY_EXPLICITLY_STOPPED] as Boolean,
            activeTaskSessionId =
                map[AndroidProtectionProtocolPersistence.KEY_ACTIVE_TASK_SESSION_ID] as String?,
            activeTaskEpoch =
                map[AndroidProtectionProtocolPersistence.KEY_ACTIVE_TASK_EPOCH] as Long?,
            activeTaskIncarnationId =
                map[AndroidProtectionProtocolPersistence.KEY_ACTIVE_TASK_INCARNATION_ID] as String?,
            nextTaskGeneration =
                map[AndroidProtectionProtocolPersistence.KEY_NEXT_TASK_GENERATION] as Long,
            activeStartAttemptId =
                map[AndroidProtectionProtocolPersistence.KEY_ACTIVE_START_ATTEMPT_ID] as String?,
            activeStartProcessId =
                map[AndroidProtectionProtocolPersistence.KEY_ACTIVE_START_PROCESS_ID] as String?,
            taskPhase = TaskPhase.fromWire(
                map[AndroidProtectionProtocolPersistence.KEY_TASK_PHASE] as String?,
            ),
            nativeStartUnresolved =
                map[AndroidProtectionProtocolPersistence.KEY_NATIVE_START_UNRESOLVED] as Boolean,
        )
    }

    override fun writeFullTuple(tuple: ProtectionProtocolTuple): Boolean {
        // Mirror Android: mutate the process-local map even when commit() returns false.
        map[AndroidProtectionProtocolPersistence.KEY_SCHEMA_VERSION] = tuple.schemaVersion.toLong()
        map[AndroidProtectionProtocolPersistence.KEY_REVISION] = tuple.revision
        map[AndroidProtectionProtocolPersistence.KEY_BACKGROUND_MODE_PREFERRED] =
            tuple.backgroundModePreferred
        map[AndroidProtectionProtocolPersistence.KEY_PROTECTION_ENABLED] = tuple.protectionEnabled
        map[AndroidProtectionProtocolPersistence.KEY_BACKGROUND_RUNTIME_ENABLED] =
            tuple.backgroundRuntimeEnabled
        map[AndroidProtectionProtocolPersistence.KEY_EXPLICITLY_STOPPED] = tuple.explicitlyStopped
        putNullable(AndroidProtectionProtocolPersistence.KEY_ACTIVE_TASK_SESSION_ID, tuple.activeTaskSessionId)
        putNullable(AndroidProtectionProtocolPersistence.KEY_ACTIVE_TASK_EPOCH, tuple.activeTaskEpoch)
        putNullable(
            AndroidProtectionProtocolPersistence.KEY_ACTIVE_TASK_INCARNATION_ID,
            tuple.activeTaskIncarnationId,
        )
        map[AndroidProtectionProtocolPersistence.KEY_NEXT_TASK_GENERATION] = tuple.nextTaskGeneration
        putNullable(
            AndroidProtectionProtocolPersistence.KEY_ACTIVE_START_ATTEMPT_ID,
            tuple.activeStartAttemptId,
        )
        putNullable(
            AndroidProtectionProtocolPersistence.KEY_ACTIVE_START_PROCESS_ID,
            tuple.activeStartProcessId,
        )
        map[AndroidProtectionProtocolPersistence.KEY_TASK_PHASE] = tuple.taskPhase.wireName
        map[AndroidProtectionProtocolPersistence.KEY_NATIVE_START_UNRESOLVED] =
            tuple.nativeStartUnresolved
        map[AndroidProtectionProtocolPersistence.KEY_LEGACY_BACKGROUND_PROTECTION_ENABLED] =
            tuple.backgroundRuntimeEnabled
        map[AndroidProtectionProtocolPersistence.KEY_LEGACY_BACKGROUND_EXPLICITLY_STOPPED] =
            tuple.explicitlyStopped
        return commitSucceeds
    }

    override fun hasForcedBackgroundDefaultOn(): Boolean =
        map[AndroidProtectionProtocolPersistence.KEY_FORCED_BACKGROUND_DEFAULT_ON] as? Boolean
            ?: false

    override fun markForcedBackgroundDefaultOn(): Boolean {
        map[AndroidProtectionProtocolPersistence.KEY_FORCED_BACKGROUND_DEFAULT_ON] = true
        return true
    }

    /** Simulate a corrupted in-memory prefs map after a failed commit. */
    fun corruptInMemoryMap() {
        map[AndroidProtectionProtocolPersistence.KEY_REVISION] = 999L
        map[AndroidProtectionProtocolPersistence.KEY_PROTECTION_ENABLED] = true
        map[AndroidProtectionProtocolPersistence.KEY_BACKGROUND_RUNTIME_ENABLED] = true
    }

    private fun putNullable(key: String, value: Any?) {
        if (value == null) {
            map.remove(key)
        } else {
            map[key] = value
        }
    }
}
