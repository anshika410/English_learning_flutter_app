package org.navgurukul.ella

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var piperHandler: PiperMethodHandler? = null
    private var whisperRecorder: WhisperRecorderHandler? = null
    private var audioControlHandler: AudioControlHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        piperHandler = PiperMethodHandler(this, flutterEngine)
        whisperRecorder = WhisperRecorderHandler(this, flutterEngine)
        audioControlHandler = AudioControlHandler(this, flutterEngine)
    }

    override fun onDestroy() {
        piperHandler?.dispose()
        whisperRecorder?.dispose()
        audioControlHandler?.dispose()
        super.onDestroy()
    }
}
