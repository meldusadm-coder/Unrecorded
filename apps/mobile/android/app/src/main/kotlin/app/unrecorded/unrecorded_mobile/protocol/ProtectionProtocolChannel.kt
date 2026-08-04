package app.unrecorded.unrecorded_mobile.protocol

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * MethodChannel bridge for one Flutter engine incarnation.
 * Actual detach / lease release runs from [FlutterEngine.EngineLifecycleListener]
 * posted on the main looper — not from the early task-lifecycle destroy callback.
 */
class ProtectionProtocolChannel private constructor(
    private val repository: ProtectionProtocolRepository,
    private val messenger: BinaryMessenger,
    private val engine: FlutterEngine,
    val incarnationId: String,
    val engineKind: EngineKind,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var attached = true

    private val changeListener: (ProtectionProtocolTuple) -> Unit = { tuple ->
        mainHandler.post {
            if (!attached) return@post
            channel.invokeMethod(
                "onProtocolChanged",
                mapOf(
                    "revision" to tuple.revision,
                    "engineIncarnationId" to incarnationId,
                ),
            )
        }
    }

    private val engineLifecycleListener = object : FlutterEngine.EngineLifecycleListener {
        override fun onPreEngineRestart() {
            // No-op: restart keeps the same engine instance; incarnation stays.
        }

        override fun onEngineWillDestroy() {
            // Post after synchronous pluginRegistry.destroy() so BLE detach completes first.
            mainHandler.post {
                detach()
            }
        }
    }

    init {
        channel.setMethodCallHandler(this)
        repository.addChangeListener(changeListener)
        engine.addEngineLifecycleListener(engineLifecycleListener)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getState" -> result.success(buildStateMap())
            "ensureReady" -> result.success(commitResultToMap(repository.ensureReady()))
            "commitExplicitStop" ->
                result.success(commitResultToMap(repository.commitExplicitStop()))
            "setBackgroundModePreferred" -> {
                val expected = call.argument<Number>("expectedRevision")?.toLong()
                val preferred = call.argument<Boolean>("preferred")
                if (expected == null || preferred == null) {
                    result.error("bad_args", "expectedRevision and preferred required", null)
                    return
                }
                result.success(
                    commitResultToMap(
                        repository.setBackgroundModePreferred(expected, preferred),
                    ),
                )
            }
            "beginForegroundIntent" -> {
                val expected = call.argument<Number>("expectedRevision")?.toLong()
                if (expected == null) {
                    result.error("bad_args", "expectedRevision required", null)
                    return
                }
                result.success(commitResultToMap(repository.beginForegroundIntent(expected)))
            }
            "allocateBackgroundSession" -> {
                val expected = call.argument<Number>("expectedRevision")?.toLong()
                val attemptId = call.argument<String>("attemptId")
                val processId = call.argument<String>("processId")
                if (expected == null || attemptId == null || processId == null) {
                    result.error(
                        "bad_args",
                        "expectedRevision, attemptId, and processId required",
                        null,
                    )
                    return
                }
                result.success(
                    commitResultToMap(
                        repository.allocateBackgroundSession(expected, attemptId, processId),
                    ),
                )
            }
            "cancelBackgroundAttempt" -> {
                val attemptId = call.argument<String>("attemptId")
                if (attemptId == null) {
                    result.error("bad_args", "attemptId required", null)
                    return
                }
                result.success(commitResultToMap(repository.cancelBackgroundAttempt(attemptId)))
            }
            "switchToForegroundIntent" -> {
                val expected = call.argument<Number>("expectedRevision")?.toLong()
                if (expected == null) {
                    result.error("bad_args", "expectedRevision required", null)
                    return
                }
                result.success(commitResultToMap(repository.switchToForegroundIntent(expected)))
            }
            "claimTaskIncarnation" -> {
                val expected = call.argument<Number>("expectedRevision")?.toLong()
                val sessionId = call.argument<String>("sessionId")
                val incarnationArg = call.argument<String>("incarnationId")
                if (expected == null || sessionId == null || incarnationArg == null) {
                    result.error(
                        "bad_args",
                        "expectedRevision, sessionId, and incarnationId required",
                        null,
                    )
                    return
                }
                result.success(
                    commitResultToMap(
                        repository.claimTaskIncarnation(expected, sessionId, incarnationArg),
                    ),
                )
            }
            "markTaskScannerReady" -> {
                val expected = call.argument<Number>("expectedRevision")?.toLong()
                val sessionId = call.argument<String>("sessionId")
                val epoch = call.argument<Number>("epoch")?.toLong()
                val incarnationArg = call.argument<String>("incarnationId")
                val leaseId = call.argument<String>("leaseId")
                if (expected == null ||
                    sessionId == null ||
                    epoch == null ||
                    incarnationArg == null ||
                    leaseId == null
                ) {
                    result.error(
                        "bad_args",
                        "expectedRevision, sessionId, epoch, incarnationId, and leaseId required",
                        null,
                    )
                    return
                }
                result.success(
                    commitResultToMap(
                        repository.markTaskScannerReady(
                            expected,
                            sessionId,
                            epoch,
                            incarnationArg,
                            leaseId,
                        ),
                    ),
                )
            }
            "markNativeStartResolved" -> {
                val expected = call.argument<Number>("expectedRevision")?.toLong()
                val attemptId = call.argument<String>("attemptId")
                if (expected == null || attemptId == null) {
                    result.error("bad_args", "expectedRevision and attemptId required", null)
                    return
                }
                result.success(
                    commitResultToMap(repository.markNativeStartResolved(expected, attemptId)),
                )
            }
            "finaliseSession" -> {
                val expected = call.argument<Number>("expectedRevision")?.toLong()
                val sessionId = call.argument<String>("sessionId")
                if (expected == null || sessionId == null) {
                    result.error("bad_args", "expectedRevision and sessionId required", null)
                    return
                }
                result.success(
                    commitResultToMap(repository.finaliseSession(expected, sessionId)),
                )
            }
            "reapDeadProcessStartLatch" -> {
                val expected = call.argument<Number>("expectedRevision")?.toLong()
                val processId = call.argument<String>("processId")
                if (expected == null || processId == null) {
                    result.error("bad_args", "expectedRevision and processId required", null)
                    return
                }
                result.success(
                    commitResultToMap(
                        repository.reapDeadProcessStartLatch(expected, processId),
                    ),
                )
            }
            "acquireForegroundLease" -> {
                val rollbackForAttemptId = call.argument<String>("rollbackForAttemptId")
                result.success(
                    leaseResultToMap(
                        repository.acquireForegroundLease(
                            incarnationId,
                            rollbackForAttemptId,
                        ),
                    ),
                )
            }
            "acquireTaskLease" -> {
                val sessionId = call.argument<String>("sessionId")
                val epoch = call.argument<Number>("epoch")?.toLong()
                val incarnationArg = call.argument<String>("incarnationId") ?: incarnationId
                if (sessionId == null || epoch == null) {
                    result.error("bad_args", "sessionId and epoch required", null)
                    return
                }
                result.success(
                    leaseResultToMap(
                        repository.acquireTaskLease(incarnationArg, sessionId, epoch),
                    ),
                )
            }
            "markLeaseActive" -> {
                val leaseId = call.argument<String>("leaseId")
                if (leaseId == null) {
                    result.error("bad_args", "leaseId required", null)
                    return
                }
                result.success(repository.markLeaseActive(leaseId))
            }
            "releaseLease" -> {
                val leaseId = call.argument<String>("leaseId")
                if (leaseId == null) {
                    result.error("bad_args", "leaseId required", null)
                    return
                }
                result.success(repository.releaseLease(leaseId))
            }
            "releaseLeaseForEngine" -> {
                val released = repository.releaseLeaseForEngine(incarnationId)
                result.success(released != null)
            }
            else -> result.notImplemented()
        }
    }

    fun detach() {
        if (!attached) return
        attached = false
        channel.setMethodCallHandler(null)
        repository.removeChangeListener(changeListener)
        engine.removeEngineLifecycleListener(engineLifecycleListener)
        repository.unregisterEngine(incarnationId)
        activeChannels.remove(incarnationId)
    }

    private fun buildStateMap(): Map<String, Any?> {
        val tuple = repository.readConfirmedTuple()
        val lease = repository.leaseRegistry.current()
        return mapOf(
            "engineIncarnationId" to incarnationId,
            "engineKind" to engineKind.name,
            "processInstanceId" to repository.processInstanceId,
            "persistenceUncertain" to repository.persistenceUncertain,
            "stopFenceRaised" to repository.stopFenceRaised,
            "tuple" to tuple?.toWireMap(),
            "lease" to lease?.toWireMap(),
        )
    }

    companion object {
        const val CHANNEL_NAME = "app.unrecorded/protection_protocol"

        private val activeChannels =
            java.util.concurrent.ConcurrentHashMap<String, ProtectionProtocolChannel>()

        fun attach(
            repository: ProtectionProtocolRepository,
            messenger: BinaryMessenger,
            engine: FlutterEngine,
            kind: EngineKind,
        ): ProtectionProtocolChannel {
            val incarnationId = repository.engineRegistry.register(kind)
            val channel = ProtectionProtocolChannel(
                repository = repository,
                messenger = messenger,
                engine = engine,
                incarnationId = incarnationId,
                engineKind = kind,
            )
            activeChannels[incarnationId] = channel
            return channel
        }

        fun activeIncarnations(): Set<String> = activeChannels.keys.toSet()
    }
}

private fun ProtectionProtocolTuple.toWireMap(): Map<String, Any?> = mapOf(
    "schemaVersion" to schemaVersion,
    "revision" to revision,
    "backgroundModePreferred" to backgroundModePreferred,
    "protectionEnabled" to protectionEnabled,
    "backgroundRuntimeEnabled" to backgroundRuntimeEnabled,
    "explicitlyStopped" to explicitlyStopped,
    "activeTaskSessionId" to activeTaskSessionId,
    "activeTaskEpoch" to activeTaskEpoch,
    "activeTaskIncarnationId" to activeTaskIncarnationId,
    "nextTaskGeneration" to nextTaskGeneration,
    "activeStartAttemptId" to activeStartAttemptId,
    "activeStartProcessId" to activeStartProcessId,
    "taskPhase" to taskPhase.wireName,
    "nativeStartUnresolved" to nativeStartUnresolved,
)

private fun ScannerLease.toWireMap(): Map<String, Any?> = mapOf(
    "ownerKind" to ownerKind.name,
    "leaseId" to leaseId,
    "engineIncarnationId" to engineIncarnationId,
    "taskSessionId" to taskSessionId,
    "taskEpoch" to taskEpoch,
    "phase" to phase.name,
)

private fun commitResultToMap(result: ProtocolCommitResult): Map<String, Any?> = when (result) {
    is ProtocolCommitResult.Confirmed -> mapOf(
        "status" to "confirmed",
        "tuple" to result.tuple.toWireMap(),
    )
    is ProtocolCommitResult.PersistenceUncertain -> mapOf(
        "status" to "persistenceUncertain",
        "intendedTuple" to result.intendedTuple?.toWireMap(),
        "lastConfirmedTuple" to result.lastConfirmedTuple?.toWireMap(),
    )
    is ProtocolCommitResult.Stale -> mapOf(
        "status" to "stale",
        "tuple" to result.current.toWireMap(),
    )
    is ProtocolCommitResult.Rejected -> mapOf(
        "status" to "rejected",
        "reason" to result.reason.name,
        "tuple" to result.current?.toWireMap(),
    )
}

private fun leaseResultToMap(result: ScannerLeaseAcquireResult): Map<String, Any?> = when (result) {
    is ScannerLeaseAcquireResult.Acquired -> mapOf(
        "status" to "acquired",
        "lease" to result.lease.toWireMap(),
    )
    is ScannerLeaseAcquireResult.Rejected -> mapOf(
        "status" to "rejected",
        "reason" to result.reason.name,
    )
}
