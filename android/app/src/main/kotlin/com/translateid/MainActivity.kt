package com.translateid

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import com.translateid.native.MlKitOcrWrapper
import com.translateid.native.OnnxTranslateWrapper
import com.translateid.native.SherpaOnnxWrapper
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL_NATIVE = "com.translateid/native"
    private val CHANNEL_OVERLAY = "com.translateid/overlay"
    private val CHANNEL_CAMERA = "com.translateid/camera"
    private val CHANNEL_AUDIO = "com.translateid/audio"
    private val CHANNEL_MODEL = "com.translateid/model"

    private val mediaProjectionManager by lazy { getSystemService(MediaProjectionManager::class.java) }
    private var mediaProjection: MediaProjection? = null
    private var screenCaptureService: ScreenCaptureService? = null
    private var overlayService: OverlayService? = null
    private var audioCaptureService: AudioCaptureService? = null

    private lateinit var sherpa: SherpaOnnxWrapper
    private lateinit var translate: OnnxTranslateWrapper
    private lateinit var ocr: MlKitOcrWrapper

    private var sttEventSink: EventChannel.EventSink? = null

    private val REQUEST_CODE_MEDIA_PROJECTION = 1001
    private val REQUEST_CODE_OVERLAY_PERMISSION = 1002
    private val REQUEST_CODE_AUDIO_CAPTURE = 1003
    private val REQUEST_CODE_CAMERA_PERMISSION = 1004
    private val REQUEST_CODE_STORAGE_PERMISSION = 1005

    private val methodChannel by lazy {
        MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL_NATIVE)
    }

    private val overlayEventChannel by lazy {
        EventChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL_OVERLAY)
    }

    private val cameraEventChannel by lazy {
        EventChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL_CAMERA)
    }

    private val audioEventChannel by lazy {
        EventChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL_AUDIO)
    }

    private val modelEventChannel by lazy {
        EventChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL_MODEL)
    }

    private val sttEventChannel by lazy {
        EventChannel(flutterEngine!!.dartExecutor.binaryMessenger, "${CHANNEL_NATIVE}/stt")
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        GeneratedPluginRegistrant.registerWith(flutterEngine!!)

        sherpa = SherpaOnnxWrapper()
        translate = OnnxTranslateWrapper(this)
        ocr = MlKitOcrWrapper(this)

        setupMethodChannels()
        setupEventChannels()
    }

    private fun setupMethodChannels() {
        methodChannel.setMethodCallHandler { call, result ->
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    when (call.method) {
                        "getPlatformVersion" -> result.success("Android ${Build.VERSION.RELEASE}")
                        "getModelDirectory" -> result.success(getModelDirectory().absolutePath)
                        "checkOverlayPermission" -> result.success(Settings.canDrawOverlays(this@MainActivity))
                        "requestOverlayPermission" -> requestOverlayPermission(result)
                        "checkCameraPermission" -> result.success(checkCameraPermission())
                        "requestCameraPermission" -> requestCameraPermission(result)
                        "checkStoragePermission" -> result.success(checkStoragePermission())
                        "requestStoragePermission" -> requestStoragePermission(result)
                        "startMediaProjection" -> startMediaProjection(result)
                        "stopMediaProjection" -> stopMediaProjection(result)
                        "startScreenCapture" -> startScreenCapture(call, result)
                        "stopScreenCapture" -> stopScreenCapture(result)
                        "startLiveTranslate" -> startLiveTranslate(call, result)
                        "stopLiveTranslate" -> stopLiveTranslate(result)
                        "startAudioCapture" -> startAudioCapture(result)
                        "stopAudioCapture" -> stopAudioCapture(result)
                        "showFloatingBubble" -> showFloatingBubble(call, result)
                        "hideFloatingBubble" -> hideFloatingBubble(result)
                        "updateBubblePosition" -> updateBubblePosition(call, result)
                        "showTranslationOverlay" -> showTranslationOverlay(call, result)
                        "hideTranslationOverlay" -> hideTranslationOverlay(result)
                        "showAudioSubtitle" -> showAudioSubtitle(call, result)
                        "hideAudioSubtitle" -> hideAudioSubtitle(result)

                        // Sherpa-ONNX
                        "initStt" -> initStt(call, result)
                        "initTts" -> initTts(call, result)
                        "initVad" -> initVad(call, result)
                        "initLangId" -> initLangId(call, result)
                        "sttAccept" -> sttAccept(call, result)
                        "sttGetResult" -> sttGetResult(call, result)
                        "sttReset" -> sttReset(call, result)
                        "sttIsEndpoint" -> sttIsEndpoint(call, result)
                        "ttsGenerate" -> ttsGenerate(call, result)
                        "vadProcess" -> vadProcess(call, result)
                        "langIdCompute" -> langIdCompute(call, result)
                        "destroySherpa" -> destroySherpa(call, result)
                        "sherpaStatus" -> sherpaStatus(result)

                        // CTranslate2
                        "initTranslator" -> initTranslator(call, result)
                        "translate" -> translateText(call, result)
                        "translateBatch" -> translateBatch(call, result)
                        "destroyTranslator" -> destroyTranslator(call, result)
                        "translatorStatus" -> translatorStatus(result)

                        // ML Kit OCR
                        "ocrFromBytes" -> ocrFromBytes(call, result)
                        "ocrFromBitmap" -> ocrFromBitmap(call, result)
                        "ocrSupportedLanguages" -> result.success(ocr.getSupportedLanguages())

                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    Log.e("MainActivity", "Method ${call.method} failed", e)
                    result.error("NATIVE_ERROR", e.message, null)
                }
            }
        }
    }

    private fun setupEventChannels() {
        overlayEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {}
            override fun onCancel(arguments: Any?) {}
        })

        cameraEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {}
            override fun onCancel(arguments: Any?) {}
        })

        audioEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {}
            override fun onCancel(arguments: Any?) {}
        })

        modelEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {}
            override fun onCancel(arguments: Any?) {}
        })

        sttEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { sttEventSink = events }
            override fun onCancel(arguments: Any?) { sttEventSink = null }
        })
    }

    // ============ Permissions ============

    private fun checkCameraPermission(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED

    private fun requestCameraPermission(result: MethodChannel.Result) {
        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.CAMERA), REQUEST_CODE_CAMERA_PERMISSION)
        result.success(true)
    }

    private fun checkStoragePermission(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) return Environment.isExternalStorageManager()
        return ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestStoragePermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION, Uri.parse("package:$packageName"))
            startActivityForResult(intent, REQUEST_CODE_STORAGE_PERMISSION)
        } else {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), REQUEST_CODE_STORAGE_PERMISSION)
        }
        result.success(true)
    }

    private fun requestOverlayPermission(result: MethodChannel.Result) {
        val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
        startActivityForResult(intent, REQUEST_CODE_OVERLAY_PERMISSION)
        result.success(true)
    }

    // ============ MediaProjection ============

    private fun startMediaProjection(result: MethodChannel.Result) {
        val intent = mediaProjectionManager.createScreenCaptureIntent()
        startActivityForResult(intent, REQUEST_CODE_MEDIA_PROJECTION)
        result.success(true)
    }

    private fun stopMediaProjection(result: MethodChannel.Result) {
        mediaProjection?.stop()
        mediaProjection = null
        result.success(true)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            REQUEST_CODE_MEDIA_PROJECTION -> {
                if (resultCode == Activity.RESULT_OK && data != null) {
                    mediaProjection = mediaProjectionManager.getMediaProjection(resultCode, data)
                    methodChannel.invokeMethod("mediaProjectionGranted", null)
                } else {
                    methodChannel.invokeMethod("mediaProjectionDenied", null)
                }
            }
            REQUEST_CODE_OVERLAY_PERMISSION -> {
                methodChannel.invokeMethod("overlayPermissionChanged", Settings.canDrawOverlays(this))
            }
        }
    }

    private fun getModelDirectory(): File {
        val externalFilesDir = getExternalFilesDir(null) ?: filesDir
        val modelDir = File(externalFilesDir, "models")
        if (!modelDir.exists()) modelDir.mkdirs()
        return modelDir
    }

    // ============ Screen / Overlay ============

    private fun startScreenCapture(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
        val mode = call.argument<String>("mode") ?: "screenshot"
        if (mediaProjection == null) {
            result.error("NO_PROJECTION", "MediaProjection not granted", null)
            return
        }
        screenCaptureService = ScreenCaptureService(mediaProjection!!, mode) { /* bitmap */ }
        screenCaptureService?.start()
        result.success(true)
    }

    private fun stopScreenCapture(result: MethodChannel.Result) {
        screenCaptureService?.stop()
        screenCaptureService = null
        result.success(true)
    }

    private fun startLiveTranslate(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
        result.success(true)
    }

    private fun stopLiveTranslate(result: MethodChannel.Result) {
        result.success(true)
    }

    private fun startAudioCapture(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            audioCaptureService = AudioCaptureService(this) { audioData ->
                audioEventChannel.invokeMethod("audioData", audioData)
            }
            audioCaptureService?.start()
            result.success(true)
        } else {
            result.error("UNSUPPORTED", "Audio playback capture requires Android 10+", null)
        }
    }

    private fun stopAudioCapture(result: MethodChannel.Result) {
        audioCaptureService?.stop()
        audioCaptureService = null
        result.success(true)
    }

    private fun showFloatingBubble(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
        if (!Settings.canDrawOverlays(this)) {
            result.error("NO_PERMISSION", "Overlay permission not granted", null)
            return
        }
        val config = call.argument<Map<String, Any>>("config") ?: emptyMap()
        overlayService = OverlayService(this, config)
        overlayService?.showBubble()
        result.success(true)
    }

    private fun hideFloatingBubble(result: MethodChannel.Result) {
        overlayService?.hideBubble()
        overlayService = null
        result.success(true)
    }

    private fun updateBubblePosition(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
        val x = call.argument<Double>("x")?.toFloat() ?: 0f
        val y = call.argument<Double>("y")?.toFloat() ?: 0f
        overlayService?.updateBubblePosition(x, y)
        result.success(true)
    }

    private fun showTranslationOverlay(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
        val overlays = call.argument<List<Map<String, Any>>>("overlays") ?: emptyList()
        overlayService?.showTranslationOverlays(overlays)
        result.success(true)
    }

    private fun hideTranslationOverlay(result: MethodChannel.Result) {
        overlayService?.hideTranslationOverlays(emptyList())
        result.success(true)
    }

    private fun showAudioSubtitle(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
        val text = call.argument<String>("text") ?: ""
        val config = call.argument<Map<String, Any>>("config") ?: emptyMap()
        overlayService?.showAudioSubtitle(text, config)
        result.success(true)
    }

    private fun hideAudioSubtitle(result: MethodChannel.Result) {
        overlayService?.hideAudioSubtitle()
        result.success(true)
    }

    // ============ Sherpa-ONNX ============

    private fun initStt(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id") ?: "default"
        val config = SherpaOnnxWrapper.SttConfig(
            modelPath = call.argument<String>("modelPath") ?: "",
            tokensPath = call.argument<String>("tokensPath") ?: "",
            numThreads = call.argument<Int>("numThreads") ?: 2,
            provider = call.argument<String>("provider") ?: "cpu",
            decodingMethod = call.argument<String>("decodingMethod") ?: "greedy_search",
            enableEndpoint = call.argument<Boolean>("enableEndpoint") ?: true
        )
        val ok = sherpa.createStt(id, config)
        result.success(ok)
    }

    private fun initTts(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id") ?: "default"
        val config = SherpaOnnxWrapper.TtsConfig(
            modelPath = call.argument<String>("modelPath") ?: "",
            tokensPath = call.argument<String>("tokensPath") ?: "",
            dataDir = call.argument<String>("dataDir") ?: "",
            numThreads = call.argument<Int>("numThreads") ?: 2,
            provider = call.argument<String>("provider") ?: "cpu"
        )
        result.success(sherpa.createTts(id, config))
    }

    private fun initVad(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
        val config = SherpaOnnxWrapper.VadConfig(
            modelPath = call.argument<String>("modelPath") ?: "",
            threshold = call.argument<Double>("threshold")?.toFloat() ?: 0.5f,
            minSilenceDuration = call.argument<Double>("minSilenceDuration")?.toFloat() ?: 0.5f,
            minSpeechDuration = call.argument<Double>("minSpeechDuration")?.toFloat() ?: 0.25f
        )
        result.success(sherpa.createVad(config))
    }

    private fun initLangId(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
        val config = SherpaOnnxWrapper.LangIdConfig(
            encoderPath = call.argument<String>("encoderPath") ?: "",
            decoderPath = call.argument<String>("decoderPath") ?: "",
            tokensPath = call.argument<String>("tokensPath") ?: "",
            numThreads = call.argument<Int>("numThreads") ?: 2,
            provider = call.argument<String>("provider") ?: "cpu"
        )
        result.success(sherpa.createLangId(config))
    }

    private fun sttAccept(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id") ?: "default"
        val samples = call.argument<DoubleArray>("samples")
            ?.map { it.toFloat() }?.toFloatArray() ?: FloatArray(0)
        val code = sherpa.sttAccept(id, samples)
        val text = sherpa.sttGetResult(id)
        val endpoint = sherpa.sttIsEndpoint(id)
        if (endpoint) sherpa.sttReset(id)
        result.success(mapOf(
            "code" to code,
            "text" to (text ?: ""),
            "isEndpoint" to endpoint
        ))
    }

    private fun sttGetResult(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id") ?: "default"
        result.success(sherpa.sttGetResult(id) ?: "")
    }

    private fun sttReset(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id") ?: "default"
        sherpa.sttReset(id)
        result.success(true)
    }

    private fun sttIsEndpoint(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id") ?: "default"
        result.success(sherpa.sttIsEndpoint(id))
    }

    private fun ttsGenerate(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id") ?: "default"
        val text = call.argument<String>("text") ?: ""
        val sid = call.argument<Int>("speakerId") ?: 0
        val speed = call.argument<Double>("speed")?.toFloat() ?: 1.0f
        val samples = sherpa.ttsGenerate(id, text, sid, speed)
        val sampleRate = sherpa.ttsGetSampleRate(id)
        result.success(mapOf(
            "samples" to (samples?.map { it.toDouble() } ?: emptyList<Double>()),
            "sampleRate" to sampleRate
        ))
    }

    private fun vadProcess(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
        val samples = call.argument<DoubleArray>("samples")
            ?.map { it.toFloat() }?.toFloatArray() ?: FloatArray(0)
        result.success(sherpa.vadProcess(samples))
    }

    private fun langIdCompute(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
        val samples = call.argument<DoubleArray>("samples")
            ?.map { it.toFloat() }?.toFloatArray() ?: FloatArray(0)
        result.success(sherpa.langIdCompute(samples) ?: "en")
    }

    private fun destroySherpa(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id") ?: "default"
        val type = call.argument<String>("type") ?: "stt"
        when (type) {
            "stt" -> sherpa.destroyStt(id)
            "tts" -> sherpa.destroyTts(id)
            "vad" -> sherpa.destroyVad()
            "langid" -> sherpa.destroyLangId()
        }
        result.success(true)
    }

    private fun sherpaStatus(result: MethodChannel.Result) {
        result.success(mapOf(
            "loaded" to SherpaOnnxWrapper.isLoaded()
        ))
    }

    // ============ ONNX Runtime Translation ============

    private fun initTranslator(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id") ?: "default"
        val modelPath = call.argument<String>("modelPath") ?: ""
        result.success(translate.initTranslator(id, modelPath))
    }

    private fun translateText(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id") ?: "default"
        val text = call.argument<String>("text") ?: ""
        result.success(translate.translate(id, text))
    }

    private fun translateBatch(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id") ?: "default"
        val texts = call.argument<List<String>>("texts")?.toTypedArray() ?: emptyArray()
        result.success(translate.translateBatch(id, texts)?.toList())
    }

    private fun destroyTranslator(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id") ?: "default"
        translate.destroy(id)
        result.success(true)
    }

    private fun translatorStatus(result: MethodChannel.Result) {
        result.success(mapOf("loaded" to true)) // ONNX Runtime loads lazily
    }

    // ============ ML Kit OCR ============

    private fun ocrFromBytes(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
        val bytes = call.argument<ByteArray>("bytes") ?: byteArrayOf()
        val width = call.argument<Int>("width") ?: 0
        val height = call.argument<Int>("height") ?: 0
        val rotation = call.argument<Int>("rotation") ?: 0
        val lang = call.argument<String>("language") ?: "auto"

        CoroutineScope(Dispatchers.Default).launch {
            try {
                val ocrResult = ocr.recognizeFromBytes(bytes, width, height, rotation, lang)
                withContext(Dispatchers.Main) {
                    result.success(ocrResultToMap(ocrResult))
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("OCR_ERROR", e.message, null)
                }
            }
        }
    }

    private fun ocrFromBitmap(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path") ?: ""
        val lang = call.argument<String>("language") ?: "auto"

        CoroutineScope(Dispatchers.Default).launch {
            try {
                val ocrResult = ocr.recognizeFromFile(path, lang)
                withContext(Dispatchers.Main) {
                    result.success(ocrResultToMap(ocrResult))
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("OCR_ERROR", e.message, null)
                }
            }
        }
    }

    private fun ocrResultToMap(r: MlKitOcrWrapper.OcrResult): Map<String, Any> = mapOf(
        "text" to r.text,
        "imageWidth" to r.imageSize.width,
        "imageHeight" to r.imageSize.height,
        "latency" to r.latency,
        "blocks" to r.blocks.map { b ->
            mapOf(
                "text" to b.text,
                "left" to b.boundingBox.left,
                "top" to b.boundingBox.top,
                "right" to b.boundingBox.right,
                "bottom" to b.boundingBox.bottom,
                "confidence" to b.confidence,
                "language" to b.language,
                "corners" to b.cornerPoints.map { p -> listOf(p.x, p.y) }
            )
        }
    )
}