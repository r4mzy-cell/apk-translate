package com.translateid.native

import android.content.Context
import android.util.Log
import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import ai.onnxruntime.OrtValue
import java.io.BufferedReader
import java.io.File
import java.io.FileReader
import java.io.IOException
import java.nio.LongBuffer
import java.util.*
import java.util.concurrent.ConcurrentHashMap

/**
 * ONNX Runtime Wrapper for Opus-MT Translation (Marian/encoder-decoder)
 * 
 * Expects model dir (from optimum export) containing:
 * - encoder_model.onnx (or encoder_model_quantized.onnx)
 * - decoder_model_merged.onnx (preferred, combines decoder + decoder_with_past)
 *   OR decoder_model.onnx + decoder_with_past_model.onnx
 * - tokenizer.json (HF fast tokenizer, Unigram model)
 * - config.json (optional, for decoder_start_token_id, etc.)
 * 
 * Dependency: implementation("com.microsoft.onnxruntime:onnxruntime-android:1.22.0")
 * 
 * Convert: optimum-cli export onnx --model Helsinki-NLP/opus-mt-en-id \
 *     --task translation --output_dir opus-mt-en-id-onnx --optimize O1 --quantize int8
 */
class OnnxTranslateWrapper(private val context: Context) {
    companion object {
        private const val TAG = "OnnxTranslateWrapper"
        private var _env: OrtEnvironment? = null
        fun getEnvironment(): OrtEnvironment {
            return _env ?: OrtEnvironment.getEnvironment().also { _env = it }
        }
    }

    private val sessions = mutableMapOf<String, ModelSessions>()
    private val tokenizers = mutableMapOf<String, UnigramTokenizer>()

    /** Initialize translator for a language pair */
    fun initTranslator(id: String, modelDir: String): Boolean {
        try {
            val dir = File(modelDir)
            if (!dir.exists()) {
                Log.e(TAG, "Model dir not found: ${dir.absolutePath}")
                return false
            }

            // Find encoder file
            val encoderFile = findModelFile(dir, listOf(
                "encoder_model_quantized.onnx",
                "encoder_model.onnx"
            ))
            if (encoderFile == null) {
                Log.e(TAG, "No encoder model found in $modelDir")
                return false
            }

            // Find decoder file (prefer merged or with_past for KV cache)
            val decoderFile = findModelFile(dir, listOf(
                "decoder_model_merged_quantized.onnx",
                "decoder_model_merged.onnx",
                "decoder_with_past_model_quantized.onnx",
                "decoder_with_past_model.onnx",
                "decoder_model_quantized.onnx",
                "decoder_model.onnx"
            ))
            if (decoderFile == null) {
                Log.e(TAG, "No decoder model found in $modelDir")
                return false
            }

            // Load sessions
            val sessionOptions = OrtSession.SessionOptions().apply {
                setIntraOpNumThreads(2)
                setGraphOptimizationLevel(OrtSession.SessionOptions.GraphOptimizationLevel.ORT_ENABLE_ALL)
            }
            val encoderSession = getEnvironment().createSession(encoderFile.absolutePath, sessionOptions)
            val decoderSession = getEnvironment().createSession(decoderFile.absolutePath, sessionOptions)

            // Analyze decoder session to find KV cache names
            val kvCacheInfo = analyzeDecoderKVCache(decoderSession)

            // Load tokenizer
            val tokenizer = UnigramTokenizer(dir)
            
            // Read config for decoder_start_token_id
            var decoderStartTokenId = tokenizer.eosTokenId // fallback
            val configFile = File(dir, "config.json")
            if (configFile.exists()) {
                decoderStartTokenId = readDecoderStartToken(configFile) ?: decoderStartTokenId
            }

            sessions[id] = ModelSessions(
                encoder = encoderSession,
                decoder = decoderSession,
                kvCacheInfo = kvCacheInfo,
                decoderStartTokenId = decoderStartTokenId
            )
            tokenizers[id] = tokenizer

            Log.i(TAG, "Loaded ONNX translator: $id (encoder=${encoderFile.name}, decoder=${decoderFile.name})")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load translator $id", e)
            return false
        }
    }

    private fun findModelFile(dir: File, candidates: List<String>): File? {
        for (name in candidates) {
            val f = File(dir, name)
            if (f.exists()) return f
        }
        return null
    }

    /** Analyze decoder session to map past KV inputs to present KV outputs */
    private fun analyzeDecoderKVCache(session: OrtSession): KVCacheInfo {
        val inputNames = session.inputNames.toTypedArray()
        val outputNames = session.outputNames.toTypedArray()
        
        val pastKeys = mutableMapOf<Int, Pair<String, String>>() // layer -> (key_name, value_name)
        val presentKeys = mutableMapOf<Int, Pair<String, String>>()
        
        // Pattern: past_key_values.{layer}.decoder.{key|value}
        val pastPattern = "past_key_values\\.(\\d+)\\.(decoder|encoder)\\.(key|value)".toRegex()
        val presentPattern = "present\\.(\\d+)\\.(decoder|encoder)\\.(key|value)".toRegex()
        
        for (name in inputNames) {
            val m = pastPattern.matchEntire(name)
            if (m != null) {
                val layer = m.groupValues[1].toInt()
                val which = m.groupValues[3]
                val existing = pastKeys[layer] ?: Pair("", "")
                pastKeys[layer] = if (which == "key") name to existing.second else existing.first to name
            }
        }
        
        for (name in outputNames) {
            val m = presentPattern.matchEntire(name)
            if (m != null) {
                val layer = m.groupValues[1].toInt()
                val which = m.groupValues[3]
                val existing = presentKeys[layer] ?: Pair("", "")
                presentKeys[layer] = if (which == "key") name to existing.second else existing.first to name
            }
        }
        
        // Sort by layer index
        val numLayers = pastKeys.keys.maxOrNull() ?: 0
        val orderedPast = mutableListOf<Pair<String, String>>()
        val orderedPresent = mutableListOf<Pair<String, String>>()
        for (i in 0..numLayers) {
            if (pastKeys.containsKey(i) && presentKeys.containsKey(i)) {
                orderedPast.add(pastKeys[i]!!)
                orderedPresent.add(presentKeys[i]!!)
            }
        }
        
        return KVCacheInfo(
            pastNames = orderedPast,
            presentNames = orderedPresent,
            useCacheBranch = inputNames.contains("use_cache_branch")
        )
    }

    private fun readDecoderStartToken(configFile: File): Int? {
        try {
            val json = configFile.readText()
            // Look for "decoder_start_token_id": 123
            val pattern = "\"decoder_start_token_id\"\\s*:\\s*(\\d+)".toRegex()
            val m = pattern.find(json)
            if (m != null) return m.groupValues[1].toInt()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to read decoder_start_token_id from config.json")
        }
        return null
    }

    /** Translate single text using encoder-decoder greedy decoding */
    fun translate(id: String, text: String): String? {
        val modelSessions = sessions[id] ?: return null
        val tokenizer = tokenizers[id] ?: return null

        try {
            // Encode source text
            val inputIds = tokenizer.encode(text)
            if (inputIds.isEmpty()) return ""
            
            val attentionMask = List(inputIds.size) { 1 }
            val inputLen = inputIds.size

            // --- ENCODER ---
            val encoderInputIds = OnnxTensor.createTensor(
                getEnvironment(),
                LongBuffer.wrap(inputIds.map { it.toLong() }.toLongArray()),
                longArrayOf(1, inputLen)
            )
            val encoderAttentionMask = OnnxTensor.createTensor(
                getEnvironment(),
                LongBuffer.wrap(attentionMask.map { it.toLong() }.toLongArray()),
                longArrayOf(1, inputLen)
            )
            
            val encoderInputs = hashMapOf<String, OnnxTensor>(
                "input_ids" to encoderInputIds,
                "attention_mask" to encoderAttentionMask
            )
            
            val encoderOutputs = modelSessions.encoder.run(encoderInputs)
            val encoderHiddenStates = encoderOutputs[0].value as Array<Array<FloatArray>> // [1, seq_len, hidden]
            
            // Close encoder inputs
            encoderInputIds.close()
            encoderAttentionMask.close()
            for (o in encoderOutputs) o.close()

            // --- DECODER (iterative greedy) ---
            val decoderStartId = modelSessions.decoderStartTokenId
            var decoderInputIds = intArrayOf(decoderStartId)
            val generatedIds = mutableListOf<Int>()
            val maxLen = 128 // safety limit
            
            // KV cache storage: Map from input name -> OrtValue
            val kvCache = mutableMapOf<String, OrtValue>()
            var firstStep = true
            
            for (step in 0 until maxLen) {
                // Prepare decoder inputs
                val inputNames = modelSessions.decoder.inputNames.toMutableList()
                val inputs = hashMapOf<String, OnnxTensor>()
                
                // input_ids: [1, 1] for step > 0, [1, 1] for first step
                val decoderInputTensor = OnnxTensor.createTensor(
                    getEnvironment(),
                    LongBuffer.wrap(decoderInputIds.map { it.toLong() }.toLongArray()),
                    longArrayOf(1, decoderInputIds.size)
                )
                inputs["input_ids"] = decoderInputTensor
                
                // encoder_attention_mask
                val encAttMaskTensor = OnnxTensor.createTensor(
                    getEnvironment(),
                    LongBuffer.wrap(attentionMask.map { it.toLong() }.toLongArray()),
                    longArrayOf(1, inputLen)
                )
                inputs["encoder_attention_mask"] = encAttMaskTensor
                
                // encoder_hidden_states
                val hiddenSize = encoderHiddenStates[0][0].size
                val flatHidden = FloatArray(1 * inputLen * hiddenSize)
                var idx = 0
                for (seq in encoderHiddenStates[0]) {
                    System.arraycopy(seq, 0, flatHidden, idx, hiddenSize)
                    idx += hiddenSize
                }
                val encHiddenTensor = OnnxTensor.createTensor(
                    getEnvironment(),
                    flatHidden,
                    longArrayOf(1, inputLen, hiddenSize)
                )
                inputs["encoder_hidden_states"] = encHiddenTensor
                
                // KV cache (for steps > 0)
                if (!firstStep && modelSessions.kvCacheInfo.pastNames.isNotEmpty()) {
                    for (i in modelSessions.kvCacheInfo.pastNames.indices) {
                        val (pastKey, pastValue) = modelSessions.kvCacheInfo.pastNames[i]
                        val (presentKey, presentValue) = modelSessions.kvCacheInfo.presentNames[i]
                        
                        val keyOrt = kvCache[presentKey]
                        val valOrt = kvCache[presentValue]
                        
                        if (keyOrt != null && valOrt != null) {
                            inputs[pastKey] = OnnxTensor.createTensor(getEnvironment(), keyOrt)
                            inputs[pastValue] = OnnxTensor.createTensor(getEnvironment(), valOrt)
                        }
                    }
                }
                
                // use_cache_branch if merged model
                if (modelSessions.kvCacheInfo.useCacheBranch) {
                    val useCache = OnnxTensor.createTensor(
                        getEnvironment(),
                        LongBuffer.wrap(longArrayOf(1)), // true = 1
                        longArrayOf(1)
                    )
                    inputs["use_cache_branch"] = useCache
                }
                
                // Run decoder
                val decoderOutputs = modelSessions.decoder.run(inputs)
                
                // Extract logits (first output) and KV cache
                val logits = decoderOutputs[0].value as Array<Array<FloatArray>> // [1, 1, vocab]
                val stepLogits = logits[0][0] // [vocab]
                
                // Greedy argmax
                var maxIdx = 0
                var maxVal = Float.NEGATIVE_INFINITY
                for (i in stepLogits.indices) {
                    if (stepLogits[i] > maxVal) {
                        maxVal = stepLogits[i]
                        maxIdx = i
                    }
                }
                
                // Check EOS
                if (maxIdx == tokenizer.eosTokenId) break
                
                generatedIds.add(maxIdx)
                
                // Update KV cache for next step
                if (!firstStep || modelSessions.kvCacheInfo.presentNames.isNotEmpty()) {
                    for (i in decoderOutputs.indices) {
                        val name = modelSessions.decoder.outputNames.toTypedArray()[i]
                        val ortValue = decoderOutputs[i]
                        // Only cache present.* outputs
                        if (name.startsWith("present.")) {
                            kvCache[name] = ortValue
                        } else {
                            ortValue.close()
                        }
                    }
                } else {
                    // Close all outputs for first step (no cache needed)
                    for (o in decoderOutputs) o.close()
                }
                
                // Next input: just the new token
                decoderInputIds = intArrayOf(maxIdx)
                firstStep = false
                
                // Close inputs
                decoderInputTensor.close()
                encAttMaskTensor.close()
                encHiddenTensor.close()
                if (inputs["use_cache_branch"] is OnnxTensor) (inputs["use_cache_branch"] as OnnxTensor).close()
                for ((_, v) in inputs) {
                    if (v !in listOf(decoderInputTensor, encAttMaskTensor, encHiddenTensor)) {
                        v.close()
                    }
                }
            }
            
            // Decode generated IDs
            return tokenizer.decode(generatedIds)
            
        } catch (e: Exception) {
            Log.e(TAG, "Translation failed", e)
            return null
        }
    }

    /** Translate batch */
    fun translateBatch(id: String, texts: Array<String>): Array<String>? {
        return texts.map { translate(id, it) ?: "" }.toTypedArray()
    }

    fun destroy(id: String) {
        sessions.remove(id)?.let {
            it.encoder.close()
            it.decoder.close()
        }
        tokenizers.remove(id)
    }

    fun destroyAll() {
        sessions.values.forEach { it.encoder.close(); it.decoder.close() }
        sessions.clear()
        tokenizers.clear()
    }

    // ============ Data Classes ============

    data class ModelSessions(
        val encoder: OrtSession,
        val decoder: OrtSession,
        val kvCacheInfo: KVCacheInfo,
        val decoderStartTokenId: Int
    )

    data class KVCacheInfo(
        val pastNames: List<Pair<String, String>>,
        val presentNames: List<Pair<String, String>>,
        val useCacheBranch: Boolean
    )

    // ============ Unigram Tokenizer (loads HF tokenizer.json) ============

    class UnigramTokenizer(private val modelDir: File) {
        // Unigram model: vocab {piece: id}
        private val vocab = mutableMapOf<String, Int>()
        private val idToPiece = mutableMapOf<Int, String>()
        
        var unkId = 0
        var bosId = 1
        var eosId = 2
        var padId = 1 // often same as bos for Marian

        init {
            loadTokenizer()
        }

        private fun loadTokenizer() {
            val tokenizerFile = File(modelDir, "tokenizer.json")
            if (!tokenizerFile.exists()) {
                Log.w(TAG, "tokenizer.json not found, using fallback")
                return
            }
            
            val json = tokenizerFile.readText()
            parseTokenizerJson(json)
        }

        private fun parseTokenizerJson(json: String) {
            try {
                // Parse minimal fields from tokenizer.json
                // Structure: {"model": {"type": "Unigram", "vocab": [["piece", score], ...], "unk_id": 0}, "added_tokens": [], ...}
                
                // Extract vocab array
                val vocabPattern = "\"vocab\"\\s*:\\s*\\[([\\s\\S]*?)\\]".toRegex()
                val vocabMatch = vocabPattern.find(json)
                if (vocabMatch != null) {
                    val vocabStr = vocabMatch.groupValues[1]
                    // Parse each ["piece", score] entry
                    val entryPattern = "\\[\\s*\"([^\"]*)\"\\s*,\\s*([-\\d.]+)\\s*\\]".toRegex()
                    var id = 0
                    for (m in entryPattern.findAll(vocabStr)) {
                        val piece = m.groupValues[1]
                            .replace("\\u0120", " ")  // Ġ -> space
                            .replace("\\u010a", "\n")
                            .replace("\\\"", "\"")
                            .replace("\\\\", "\\")
                        val score = m.groupValues[2].toDouble()
                        vocab[piece] = id
                        idToPiece[id] = piece
                        id++
                    }
                    
                }
                
                // Extract special token IDs
                val unkPattern = "\"unk_id\"\\s*:\\s*(\\d+)".toRegex()
                unkPattern.find(json)?.groupValues?.get(1)?.toInt()?.let { unkId = it }
                
                // added_tokens for bos/eos/pad
                val addedPattern = "\"content\"\\s*:\\s*\"([^\"]+)\"\\s*,[^}]*\"id\"\\s*:\\s*(\\d+)".toRegex()
                for (m in addedPattern.findAll(json)) {
                    val content = m.groupValues[1]
                    val id = m.groupValues[2].toInt()
                    when (content) {
                        "<s>", "<bos>" -> bosId = id
                        "</s>", "<eos>" -> eosId = id
                        "<pad>" -> padId = id
                    }
                }
                
                // Fallback: if eos still default, use vocab size - 1
                if (eosId == 2 && vocab.isNotEmpty()) eosId = vocab.size - 1
                
                Log.d(TAG, "Loaded tokenizer: vocab=${vocab.size}, unk=$unkId, bos=$bosId, eos=$eosId, pad=$padId")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to parse tokenizer.json", e)
            }
        }

        fun encode(text: String): List<Int> {
            if (vocab.isEmpty()) {
                // Fallback: char-level
                return text.toList().map { vocab.getOrDefault(it.toString(), unkId) }
            }
            
            // Simple greedy segmentation (Viterbi would be better but complex)
            // For now: longest-match piecewise (approximate)
            val pieces = mutableListOf<String>()
            var pos = 0
            while (pos < text.length) {
                var bestPiece = ""
                var bestLen = 0
                // Try longest match up to 12 chars
                for (len in 12 downTo 1) {
                    if (pos + len <= text.length) {
                        val sub = text.substring(pos, pos + len)
                        if (vocab.containsKey(sub)) {
                            bestPiece = sub
                            bestLen = len
                            break
                        }
                    }
                }
                if (bestPiece.isNotEmpty()) {
                    pieces.add(bestPiece)
                    pos += bestLen
                } else {
                    // Unknown char
                    pieces.add(text.substring(pos, pos + 1))
                    pos++
                }
            }
            
            val ids = pieces.map { vocab.getOrDefault(it, unkId) }
            return ids
        }

        fun decode(ids: List<Int>): String {
            val pieces = ids.mapNotNull { idToPiece[it] }
            // Unigram: pieces already contain space markers (Ġ)
            var result = StringBuilder()
            for (piece in pieces) {
                if (piece.startsWith("▁") || piece.startsWith("Ġ")) {
                    if (result.isNotEmpty()) result.append(" ")
                    result.append(piece.substring(1))
                } else {
                    result.append(piece)
                }
            }
            return result.toString()
        }
    }
}