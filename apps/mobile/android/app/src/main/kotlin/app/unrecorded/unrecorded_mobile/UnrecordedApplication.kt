package app.unrecorded.unrecorded_mobile

import android.app.Application
import app.unrecorded.unrecorded_mobile.protocol.AndroidProtectionProtocolPersistence
import app.unrecorded.unrecorded_mobile.protocol.EngineKind
import app.unrecorded.unrecorded_mobile.protocol.ProtectionProtocolChannel
import app.unrecorded.unrecorded_mobile.protocol.ProtectionProtocolRepository
import com.pravera.flutter_foreground_task.FlutterForegroundTaskLifecycleListener
import com.pravera.flutter_foreground_task.FlutterForegroundTaskPlugin
import com.pravera.flutter_foreground_task.FlutterForegroundTaskStarter
import io.flutter.embedding.engine.FlutterEngine

/**
 * Process-scoped Application that owns the protection protocol repository and
 * registers the foreground-task engine lifecycle listener before any task starts.
 */
class UnrecordedApplication : Application() {
    lateinit var protectionProtocolRepository: ProtectionProtocolRepository
        private set

    private val taskLifecycleListener = object : FlutterForegroundTaskLifecycleListener {
        override fun onEngineCreate(flutterEngine: FlutterEngine?) {
            // Nullable engine fails closed: no channel → task cannot obtain lease/protocol.
            if (flutterEngine == null) return
            ProtectionProtocolChannel.attach(
                repository = protectionProtocolRepository,
                messenger = flutterEngine.dartExecutor.binaryMessenger,
                engine = flutterEngine,
                kind = EngineKind.TASK,
            )
        }

        override fun onTaskStart(starter: FlutterForegroundTaskStarter) = Unit

        override fun onTaskRepeatEvent() = Unit

        override fun onTaskDestroy() = Unit

        override fun onEngineWillDestroy() {
            // Intentionally ignored. 9.2.2 invokes this before asynchronous Dart onDestroy
            // completes; real detach is FlutterEngine.EngineLifecycleListener + main-looper post.
        }
    }

    override fun onCreate() {
        super.onCreate()
        protectionProtocolRepository = ProtectionProtocolRepository(
            AndroidProtectionProtocolPersistence(this),
        )
        FlutterForegroundTaskPlugin.addTaskLifecycleListener(taskLifecycleListener)
    }

    companion object {
        fun from(application: Application): UnrecordedApplication {
            return application as UnrecordedApplication
        }
    }
}
