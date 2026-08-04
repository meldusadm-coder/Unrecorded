package app.unrecorded.unrecorded_mobile.protocol

import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong

/**
 * Process-scoped Flutter engine incarnation registry.
 * Alive until actual [io.flutter.embedding.engine.FlutterEngine.destroy] cleanup runs.
 */
class ProtectionEngineRegistry(
    val processInstanceId: String,
) {
    private val counter = AtomicLong(0)
    private val engines = ConcurrentHashMap<String, EngineKind>()

    fun register(kind: EngineKind): String {
        val incarnationId = "$processInstanceId:${counter.incrementAndGet()}"
        engines[incarnationId] = kind
        return incarnationId
    }

    fun unregister(incarnationId: String) {
        engines.remove(incarnationId)
    }

    fun contains(incarnationId: String): Boolean = engines.containsKey(incarnationId)

    fun kindOf(incarnationId: String): EngineKind? = engines[incarnationId]

    fun hasTaskEngine(): Boolean = engines.values.any { it == EngineKind.TASK }

    fun hasMainEngine(): Boolean = engines.values.any { it == EngineKind.MAIN }

    fun registeredIncarnations(): Set<String> = engines.keys.toSet()

    fun isEmpty(): Boolean = engines.isEmpty()
}
