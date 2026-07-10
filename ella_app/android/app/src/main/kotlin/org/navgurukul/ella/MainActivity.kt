package org.navgurukul.ella

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var ttsPlugin: NativeTtsPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ella/native_tts")
        ttsPlugin = NativeTtsPlugin(this, channel)
        channel.setMethodCallHandler(ttsPlugin)
    }

    override fun onPause() {
        ttsPlugin?.stop()
        super.onPause()
    }

    override fun onDestroy() {
        ttsPlugin?.dispose()
        super.onDestroy()
    }
}
