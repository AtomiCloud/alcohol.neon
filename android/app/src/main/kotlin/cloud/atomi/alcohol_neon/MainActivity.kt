package cloud.atomi.alcohol_neon

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        NextUpNotification.register(this, flutterEngine.dartExecutor.binaryMessenger)
    }
}
