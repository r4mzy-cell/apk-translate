package com.translateid.native

import android.content.Context
import android.content.res.AssetManager
import android.util.Log
import com.k2fsa.sherpa.onnx.*

/**
 * Sherpa-ONNX JNI Wrapper for Android
 *
 * Delegates to official sherpa-onnx Kotlin API (com.k2fsa.sherpa.onnx.*)
 * Requires libsherpa-onnx-jni.so + dependencies in jniLibs/{arm64-v8a,armeabi-v7a}
 */
class SherpaOnnxWrapper(private val context: Context) {

    companion object {
        private const val TAG = "SherpaOnnxWrapper"
        @Volatile private var _isLoaded = false

        /** Load the native library (delegated to official classes) */
        fun loadLibrary(): Boolean {
            if (_isLoaded) return true
            return try {
                // Trigger loading via any official class companion
                System.loadLibrary("sherpa-onnx-jni")
                _isLoaded = true
                Log.i(TAG, "Sherpa-ONNX library loaded successfully")
                true
            } catch (e: UnsatisfiedLinkError) {
                Log.e(TAG, "Failed to load sherpa-onnx-jni: ${e.message}")
                false
            }
        }

        fun isLoaded(): Boolean = _isLoaded
    }

    // ============ STT (Streaming Speech-to-Text) ============

    private var sttRecognizer: OnlineRecognizer? = null
    private val sttStreams = mutableMapOf<String, OnlineStream>()

    fun createStt(id: String, config: SttConfig): Boolean {
        if (!loadLibrary()) return false
        if (sttRecognizer != null) return false // already created

        // Build OnlineRecognizerConfig from our simpler SttConfig
        val modelConfig = OnlineModelConfig(
            zipformer2Ctc = OnlineZipformer2CtcModelConfig(model = config.modelPath),
            tokens = config.tokensPath,
            numThreads = config.numThreads,
            provider = config.provider,
            modelType = "zipformer2",
            debug = false
        )

        val recognizerConfig = OnlineRecognizerConfig(
            modelConfig = modelConfig,
            lmConfig = OnlineLMConfig(model = config.lmPath, scale = config.lmScale),
            decodingMethod = config.decodingMethod,
            maxActivePaths = config.maxActivePaths,
            hotwordsFile = config.hotwordsFile,
            hotwordsScore = config.hotwordsScore,
            blankPenalty = config.blankPenalty,
            enableEndpoint = config.enableEndpoint,
            endpointConfig = EndpointConfig(
                rule1 = EndpointRule(false, config.endpointRule1, 0f),
                rule2 = EndpointRule(true, config.endpointRule2, 0f),
                rule3 = EndpointRule(false, 0f, config.endpointRule3)
            ),
            ruleFsts = config.ruleFsts,
            ruleFars = config.ruleFars
        )

        sttRecognizer = OnlineRecognizer(null, recognizerConfig)
        return sttRecognizer != null
    }

    fun sttAccept(id: String, samples: FloatArray): Int {
        val recognizer = sttRecognizer ?: return -1
        val stream = sttStreams.getOrPut(id) { recognizer.createStream() }
        stream.acceptWaveform(samples, 16000)
        recognizer.decode(stream)
        return if (recognizer.isReady(stream)) 1 else 0
    }

    fun sttGetResult(id: String): String? {
        val stream = sttStreams[id] ?: return null
        val recognizer = sttRecognizer ?: return null
        return recognizer.getResult(stream).text
    }

    fun sttIsEndpoint(id: String): Boolean {
        val stream = sttStreams[id] ?: return false
        val recognizer = sttRecognizer ?: return false
        return recognizer.isEndpoint(stream)
    }

    fun sttReset(id: String) {
        val stream = sttStreams[id] ?: return
        val recognizer = sttRecognizer ?: return
        recognizer.reset(stream)
    }

    fun sttCreateStream(id: String): Boolean {
        val recognizer = sttRecognizer ?: return false
        val stream = recognizer.createStream()
        sttStreams[id] = stream
        return true
    }

    fun destroyStt(id: String) {
        sttStreams.remove(id)?.release()
    }

    fun destroyAllStt() {
        sttStreams.values.forEach { it.release() }
        sttStreams.clear()
        sttRecognizer?.release()
        sttRecognizer = null
    }

    // ============ TTS (Text-to-Speech) ============

    private val ttsEngines = mutableMapOf<String, OfflineTts>()

    fun createTts(id: String, config: TtsConfig): Boolean {
        if (!loadLibrary()) return false

        // Build OfflineTtsConfig for Piper VITS model
        // If dataDir points to espeak-ng-data, it enables on-device phonemization
        // Otherwise model expects pre-phonemized input (phonemeCodepoints)
        val ttsConfig = OfflineTtsConfig(
            model = OfflineTtsModelConfig(
                vits = OfflineTtsVitsModelConfig(
                    model = config.modelPath,
                    tokens = config.tokensPath,
                    lexicon = "",
                    dataDir = config.dataDir  // espeak-ng-data directory (optional)
                ),
                numThreads = config.numThreads,
                debug = config.debug,
                provider = config.provider
            ),
            ruleFsts = "",
            ruleFars = ""
        )

        val tts = OfflineTts(null, ttsConfig)
        ttsEngines[id] = tts
        return true
    }

    fun ttsGenerate(id: String, text: String, speakerId: Int, speed: Float): FloatArray? {
        val tts = ttsEngines[id] ?: return null
        val audio = tts.generate(text = text, sid = speakerId, speed = speed)
        return audio.samples
    }

    fun ttsGetSampleRate(id: String): Int {
        val tts = ttsEngines[id] ?: return 0
        return tts.sampleRate()
    }

    fun destroyTts(id: String) {
        ttsEngines.remove(id)?.free()
    }

    // ============ VAD (Voice Activity Detection) ============

    private var vad: Vad? = null

    fun createVad(config: VadConfig): Boolean {
        if (!loadLibrary()) return false

        val vadConfig = VadModelConfig(
            sileroVadModelConfig = SileroVadModelConfig(
                model = config.modelPath,
                threshold = config.threshold,
                minSilenceDuration = config.minSilenceDuration,
                minSpeechDuration = config.minSpeechDuration,
                windowSize = config.windowSize
            ),
            sampleRate = 16000,
            numThreads = 1,
            provider = "cpu"
        )

        vad = Vad(null, vadConfig)
        return vad != null
    }

    fun vadProcess(samples: FloatArray): Int {
        val v = vad ?: return -1
        v.acceptWaveform(samples)
        return if (v.isSpeechDetected()) 1 else 0
    }

    fun destroyVad() {
        vad?.release()
        vad = null
    }

    // ============ Language Identification ============

    private var langId: SpokenLanguageIdentification? = null

    fun createLangId(config: LangIdConfig): Boolean {
        if (!loadLibrary()) return false

        val langIdConfig = SpokenLanguageIdentificationConfig(
            whisper = SpokenLanguageIdentificationWhisperConfig(
                encoder = config.encoderPath,
                decoder = config.decoderPath
            ),
            numThreads = config.numThreads,
            provider = config.provider
        )

        langId = SpokenLanguageIdentification(null, langIdConfig)
        return langId != null
    }

    fun langIdCompute(samples: FloatArray): String? {
        val l = langId ?: return null
        val stream = l.createStream()
        stream.acceptWaveform(samples, 16000)
        val lang = l.compute(stream)
        stream.release()
        return lang
    }

    fun destroyLangId() {
        langId?.release()
        langId = null
    }

    // ============ Helper Classes ============

    /** STT Configuration */
    data class SttConfig(
        val modelPath: String,
        val tokensPath: String,
        val numThreads: Int = 2,
        val provider: String = "cpu",
        val decodingMethod: String = "greedy_search",
        val ruleFsts: String = "",
        val ruleFars: String = "",
        val hotwordsFile: String = "",
        val hotwordsScore: Float = 1.5f,
        val blankPenalty: Float = 0.0f,
        val ctcWeight: Float = 0.5f,
        val lmPath: String = "",
        val lmScale: Float = 0.5f,
        val enableEndpoint: Boolean = true,
        val endpointRule1: Float = 2.4f,
        val endpointRule2: Float = 1.2f,
        val endpointRule3: Float = 3.0f,
        val maxActivePaths: Int = 4
    )

    /** TTS Configuration */
    data class TtsConfig(
        val modelPath: String,
        val tokensPath: String,
        val dataDir: String,
        val numThreads: Int = 2,
        val provider: String = "cpu",
        val debug: Boolean = false
    )

    /** VAD Configuration */
    data class VadConfig(
        val modelPath: String,
        val threshold: Float = 0.5f,
        val minSilenceDuration: Float = 0.5f,
        val minSpeechDuration: Float = 0.25f,
        val windowSize: Int = 512
    )

    /** LangID Configuration */
    data class LangIdConfig(
        val encoderPath: String,
        val decoderPath: String,
        val tokensPath: String,
        val numThreads: Int = 2,
        val provider: String = "cpu"
    )
}