package com.translateid.native

import android.content.Context
import android.util.Log

/**
 * Sherpa-ONNX JNI Wrapper for Android
 *
 * This class provides Kotlin bindings to the Sherpa-ONNX C++ API via JNI.
 * Requires libsherpa-onnx-jni.so in jniLibs/{arm64-v8a,armeabi-v7a}
 *
 * Prebuilt binaries: https://github.com/k2-fsa/sherpa-onnx/releases
 * Models: https://github.com/k2-fsa/sherpa-onnx/releases/tag/asr-models
 *         https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models
 */
class SherpaOnnxWrapper {
    companion object {
        private const val TAG = "SherpaOnnxWrapper"
        private var _isLoaded = false

        /** Load the native library */
        fun loadLibrary(): Boolean {
            if (_isLoaded) return true
            return try {
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

        // ============ STT (Speech-to-Text) ============

        /** Create a streaming recognizer */
        @JvmStatic
        external fun sttCreate(
            modelPath: String,
            tokensPath: String,
            numThreads: Int,
            provider: String,
            decodingMethod: String,
            ruleFsts: String,
            ruleFars: String,
            hotwordsFile: String,
            hotwordsScore: Float,
            blankPenalty: Float,
            ctcWeight: Float,
            lmPath: String,
            lmScale: Float,
            enableEndpoint: Boolean,
            endpointRule1: Float,
            endpointRule2: Float,
            endpointRule3: Float,
            maxActivePaths: Int
        ): Long

        /** Accept waveform samples (float32, 16kHz) */
        @JvmStatic
        external fun sttAcceptWaveform(recognizerHandle: Long, samples: FloatArray): Int

        /** Get current recognition result */
        @JvmStatic
        external fun sttGetResult(recognizerHandle: Long): String?

        /** Check if endpoint detected */
        @JvmStatic
        external fun sttIsEndpoint(recognizerHandle: Long): Boolean

        /** Reset recognizer for new utterance */
        @JvmStatic
        external fun sttReset(recognizerHandle: Long): Unit

        /** Destroy recognizer */
        @JvmStatic
        external fun sttDestroy(recognizerHandle: Long): Unit

        // ============ TTS (Text-to-Speech) ============

        /** Create TTS engine */
        @JvmStatic
        external fun ttsCreate(
            modelPath: String,
            tokensPath: String,
            dataDir: String,
            numThreads: Int,
            provider: String,
            debug: Boolean
        ): Long

        /** Generate speech from text */
        @JvmStatic
        external fun ttsGenerate(
            ttsHandle: Long,
            text: String,
            sid: Int,
            speed: Float
        ): FloatArray?

        /** Get sample rate */
        @JvmStatic
        external fun ttsGetSampleRate(ttsHandle: Long): Int

        /** Destroy TTS engine */
        @JvmStatic
        external fun ttsDestroy(ttsHandle: Long): Unit

        // ============ VAD (Voice Activity Detection) ============

        /** Create VAD detector */
        @JvmStatic
        external fun vadCreate(
            modelPath: String,
            threshold: Float,
            minSilenceDuration: Float,
            minSpeechDuration: Float,
            windowSize: Int
        ): Long

        /** Process audio frame for VAD */
        @JvmStatic
        external fun vadProcess(vadHandle: Long, samples: FloatArray): Int

        /** Destroy VAD */
        @JvmStatic
        external fun vadDestroy(vadHandle: Long): Unit

        // ============ Language Identification ============

        /** Create LangID detector */
        @JvmStatic
        external fun langIdCreate(
            encoderPath: String,
            decoderPath: String,
            tokensPath: String,
            numThreads: Int,
            provider: String
        ): Long

        /** Identify language from audio */
        @JvmStatic
        external fun langIdCompute(langIdHandle: Long, samples: FloatArray): String?

        /** Destroy LangID */
        @JvmStatic
        external fun langIdDestroy(langIdHandle: Long): Unit
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

    // ============ Managed Instances ============

    private val sttHandles = mutableMapOf<String, Long>()
    private val ttsHandles = mutableMapOf<String, Long>()
    private var vadHandle: Long? = null
    private var langIdHandle: Long? = null

    fun createStt(id: String, config: SttConfig): Boolean {
        if (!loadLibrary()) return false
        val handle = sttCreate(
            config.modelPath, config.tokensPath, config.numThreads, config.provider,
            config.decodingMethod, config.ruleFsts, config.ruleFars,
            config.hotwordsFile, config.hotwordsScore, config.blankPenalty,
            config.ctcWeight, config.lmPath, config.lmScale,
            config.enableEndpoint, config.endpointRule1, config.endpointRule2,
            config.endpointRule3, config.maxActivePaths
        )
        if (handle > 0) {
            sttHandles[id] = handle
            return true
        }
        return false
    }

    fun sttAccept(id: String, samples: FloatArray): Int {
        val handle = sttHandles[id] ?: return -1
        return sttAcceptWaveform(handle, samples)
    }

    fun sttGetResult(id: String): String? {
        val handle = sttHandles[id] ?: return null
        return sttGetResult(handle)
    }

    fun sttIsEndpoint(id: String): Boolean {
        val handle = sttHandles[id] ?: return false
        return sttIsEndpoint(handle)
    }

    fun sttReset(id: String) {
        val handle = sttHandles[id] ?: return
        sttReset(handle)
    }

    fun destroyStt(id: String) {
        val handle = sttHandles.remove(id) ?: return
        sttDestroy(handle)
    }

    fun createTts(id: String, config: TtsConfig): Boolean {
        if (!loadLibrary()) return false
        val handle = ttsCreate(
            config.modelPath, config.tokensPath, config.dataDir,
            config.numThreads, config.provider, config.debug
        )
        if (handle > 0) {
            ttsHandles[id] = handle
            return true
        }
        return false
    }

    fun ttsGenerate(id: String, text: String, speakerId: Int, speed: Float): FloatArray? {
        val handle = ttsHandles[id] ?: return null
        return ttsGenerate(handle, text, speakerId, speed)
    }

    fun ttsGetSampleRate(id: String): Int {
        val handle = ttsHandles[id] ?: return 0
        return ttsGetSampleRate(handle)
    }

    fun destroyTts(id: String) {
        val handle = ttsHandles.remove(id) ?: return
        ttsDestroy(handle)
    }

    fun createVad(config: VadConfig): Boolean {
        if (!loadLibrary()) return false
        vadHandle = vadCreate(
            config.modelPath, config.threshold, config.minSilenceDuration,
            config.minSpeechDuration, config.windowSize
        )
        return vadHandle != null && vadHandle!! > 0
    }

    fun vadProcess(samples: FloatArray): Int {
        val handle = vadHandle ?: return -1
        return vadProcess(handle, samples)
    }

    fun destroyVad() {
        vadHandle?.let { vadDestroy(it) }
        vadHandle = null
    }

    fun createLangId(config: LangIdConfig): Boolean {
        if (!loadLibrary()) return false
        langIdHandle = langIdCreate(
            config.encoderPath, config.decoderPath, config.tokensPath,
            config.numThreads, config.provider
        )
        return langIdHandle != null && langIdHandle!! > 0
    }

    fun langIdCompute(samples: FloatArray): String? {
        val handle = langIdHandle ?: return null
        return langIdCompute(handle, samples)
    }

    fun destroyLangId() {
        langIdHandle?.let { langIdDestroy(it) }
        langIdHandle = null
    }
}