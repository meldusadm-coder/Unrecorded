package app.unrecorded.unrecorded_mobile

import app.unrecorded.unrecorded_mobile.protocol.EngineKind
import app.unrecorded.unrecorded_mobile.protocol.ProtectionProtocolChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val app = UnrecordedApplication.from(application)
        ProtectionProtocolChannel.attach(
            repository = app.protectionProtocolRepository,
            messenger = flutterEngine.dartExecutor.binaryMessenger,
            engine = flutterEngine,
            kind = EngineKind.MAIN,
        )
    }
}
