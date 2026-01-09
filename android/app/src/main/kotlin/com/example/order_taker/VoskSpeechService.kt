package com.example.order_taker

import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.cancel
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import org.json.JSONObject
import org.vosk.Model
import org.vosk.Recognizer
import kotlin.math.max

class VoskSpeechService(private val context: Context) {
    private var model: Model? = null
    private var recognizer: Recognizer? = null
    private var audioRecord: AudioRecord? = null
    private var sink: EventChannel.EventSink? = null

    private var sampleRate: Int = 16000
    private var job: Job? = null

    private val uiScope = MainScope()

    fun setEventSink(s: EventChannel.EventSink?) {
        sink = s
    }

    fun init(modelPath: String, sr: Int, result: MethodChannel.Result) {
        try {
            sampleRate = sr
            recognizer?.close()
            model?.close()
            model = Model(modelPath)
            recognizer = Recognizer(model, sampleRate.toFloat())
            result.success(null)
        } catch (e: Exception) {
            result.error("VOSK_INIT", e.message, null)
        }
    }

    fun start(result: MethodChannel.Result) {
        try {
            if (job != null) {
                result.success(null)
                return
            }

            val r = recognizer ?: run {
                result.error("VOSK_START", "Recognizer not initialized", null)
                return
            }

            val minBuf = AudioRecord.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )

            if (minBuf == AudioRecord.ERROR || minBuf == AudioRecord.ERROR_BAD_VALUE) {
                result.error("VOSK_AUDIO", "Invalid AudioRecord buffer size", null)
                return
            }

            val bufferSize = max(minBuf, 4096)

            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                bufferSize
            )

            val ar = audioRecord
            if (ar == null || ar.state != AudioRecord.STATE_INITIALIZED) {
                audioRecord?.release()
                audioRecord = null
                result.error("VOSK_AUDIO", "AudioRecord not initialized", null)
                return
            }

            ar.startRecording()

            job = CoroutineScope(Dispatchers.Default).launch {
                val buffer = ByteArray(bufferSize)
                while (isActive) {
                    val n = ar.read(buffer, 0, buffer.size)
                    if (n <= 0) continue
                    val ok = r.acceptWaveForm(buffer, n)
                    if (ok) emitOnMain(r.result, true) else emitOnMain(r.partialResult, false)
                }
            }

            result.success(null)
        } catch (e: Exception) {
            result.error("VOSK_START", e.message, null)
        }
    }

    fun stop(result: MethodChannel.Result) {
        try {
            job?.cancel()
            job = null

            audioRecord?.let {
                try { it.stop() } catch (_: Throwable) {}
                it.release()
            }
            audioRecord = null

            result.success(null)
        } catch (e: Exception) {
            result.error("VOSK_STOP", e.message, null)
        }
    }

    fun dispose(result: MethodChannel.Result) {
        try {
            stop(object : MethodChannel.Result {
                override fun success(r: Any?) {}
                override fun error(code: String, message: String?, details: Any?) {}
                override fun notImplemented() {}
            })

            recognizer?.close()
            recognizer = null

            model?.close()
            model = null

            uiScope.cancel()

            result.success(null)
        } catch (e: Exception) {
            result.error("VOSK_DISPOSE", e.message, null)
        }
    }

    private fun emitOnMain(json: String, isFinal: Boolean) {
        val obj = JSONObject(json)
        val text = when {
            obj.has("text") -> obj.optString("text")
            obj.has("partial") -> obj.optString("partial")
            else -> ""
        }

        val payload = hashMapOf<String, Any>(
            "text" to text,
            "isFinal" to isFinal,
            "raw" to jsonToMap(obj)
        )

        uiScope.launch(Dispatchers.Main.immediate) {
            sink?.success(payload)
        }
    }

    private fun jsonToMap(obj: JSONObject): HashMap<String, Any> {
        val map = HashMap<String, Any>()
        val keys = obj.keys()
        while (keys.hasNext()) {
            val k = keys.next()
            map[k] = obj.get(k)
        }
        return map
    }
}
