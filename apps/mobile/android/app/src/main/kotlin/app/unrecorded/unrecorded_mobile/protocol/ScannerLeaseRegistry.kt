package app.unrecorded.unrecorded_mobile.protocol

import java.util.UUID
import java.util.concurrent.atomic.AtomicReference

/**
 * Exactly one exclusive scanner lease per Android process.
 * Acquisition is lock-free CAS against the current holder; callers still gate on Stop /
 * persistence fences before invoking [tryAcquire].
 */
class ScannerLeaseRegistry {
    private val holder = AtomicReference<ScannerLease?>(null)

    fun current(): ScannerLease? = holder.get()

    fun tryAcquire(
        ownerKind: ScannerLeaseOwnerKind,
        engineIncarnationId: String,
        taskSessionId: String? = null,
        taskEpoch: Long? = null,
        stopFenceRaised: Boolean,
        persistenceUncertain: Boolean,
        enginePresent: Boolean,
        additionalGuardOk: Boolean = true,
    ): ScannerLeaseAcquireResult {
        if (persistenceUncertain) {
            return ScannerLeaseAcquireResult.Rejected(ScannerLeaseRejectReason.PERSISTENCE_UNCERTAIN)
        }
        if (stopFenceRaised) {
            return ScannerLeaseAcquireResult.Rejected(ScannerLeaseRejectReason.STOP_FENCE)
        }
        if (!enginePresent) {
            return ScannerLeaseAcquireResult.Rejected(ScannerLeaseRejectReason.ENGINE_ABSENT)
        }
        if (!additionalGuardOk) {
            return ScannerLeaseAcquireResult.Rejected(ScannerLeaseRejectReason.GUARD_FAILED)
        }

        val lease = ScannerLease(
            ownerKind = ownerKind,
            leaseId = UUID.randomUUID().toString(),
            engineIncarnationId = engineIncarnationId,
            taskSessionId = taskSessionId,
            taskEpoch = taskEpoch,
            phase = ScannerLeasePhase.STARTING,
        )

        while (true) {
            val existing = holder.get()
            if (existing != null) {
                return ScannerLeaseAcquireResult.Rejected(ScannerLeaseRejectReason.LEASE_HELD)
            }
            if (holder.compareAndSet(null, lease)) {
                return ScannerLeaseAcquireResult.Acquired(lease)
            }
        }
    }

    fun markActive(leaseId: String): Boolean {
        while (true) {
            val existing = holder.get() ?: return false
            if (existing.leaseId != leaseId) return false
            if (existing.phase == ScannerLeasePhase.ACTIVE) return true
            val updated = existing.copy(phase = ScannerLeasePhase.ACTIVE)
            if (holder.compareAndSet(existing, updated)) return true
        }
    }

    fun markStopping(leaseId: String): Boolean {
        while (true) {
            val existing = holder.get() ?: return false
            if (existing.leaseId != leaseId) return false
            val updated = existing.copy(phase = ScannerLeasePhase.STOPPING)
            if (holder.compareAndSet(existing, updated)) return true
        }
    }

    fun release(leaseId: String): Boolean {
        while (true) {
            val existing = holder.get() ?: return false
            if (existing.leaseId != leaseId) return false
            if (holder.compareAndSet(existing, null)) return true
        }
    }

    fun releaseIfOwnedBy(engineIncarnationId: String): ScannerLease? {
        while (true) {
            val existing = holder.get() ?: return null
            if (existing.engineIncarnationId != engineIncarnationId) return null
            if (holder.compareAndSet(existing, null)) return existing
        }
    }
}
