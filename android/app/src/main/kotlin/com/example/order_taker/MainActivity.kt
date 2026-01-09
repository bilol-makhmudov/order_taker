package com.example.order_taker

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private lateinit var speechService: VoskSpeechService

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        speechService = VoskSpeechService(applicationContext)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "order_taker/vosk"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "init" -> {
                    val modelPath = call.argument<String>("modelPath") ?: ""
                    val sampleRate = call.argument<Int>("sampleRate") ?: 16000
                    speechService.init(modelPath, sampleRate, result)
                }
                "start" -> speechService.start(result)
                "stop" -> speechService.stop(result)
                "dispose" -> speechService.dispose(result)
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "order_taker/vosk_events"
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                speechService.setEventSink(events)
            }

            override fun onCancel(arguments: Any?) {
                speechService.setEventSink(null)
            }
        })
    }
}
