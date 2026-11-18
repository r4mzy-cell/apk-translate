package com.translateid.native

import android.content.Context
import android.util.Log
import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import java.io.File
import java.nio.FloatBuffer
import java.nio.LongBuffer

/**
 * ONNX Runtime translation wrapper for Opus-MT (Marian encoder-decoder).
 *
 * Model dir (optimum export) must contain:
 * - encoder_model_quantized.onnx (or encoder_model.onnx)
 * - decoder_model_quantized.onnx  (plain decoder, no KV cache inputs)
 * - tokenizer.json
 * - config.json (optional; decoder_start_token_id)
 *
 * We use the plain (non-past) decoder and re-feed the growing decoder
 * input each step. Simpler and correct; fine for short sentences.
 */
class OnnxTranslateWrapper(private val context: Context) {
    companion object {
        private const val TAG = "OnnxTranslateWrapper"
        private var env: OrtEnvironment? = null
        fun getEnvironment(): OrtEnvironment =
            env ?: OrtEnvironment.getEnvironment().also { env = it }
    }

    private data class Sessions(
        val encoder: OrtSession,
        val decoder: OrtSession,
        val tokenizer: UnigramTokenizer,
        val decoderStartTokenId: Int
    )

    private val sessions = mutableMapOf<String, Sessions>()

    fun initTranslator(id: String, modelDir: String): Boolean {
        try {
            val dir = File(modelDir)
            if (!dir.exists()) {
                Log.e(TAG, "Model dir not found: ${dir.absolutePath}")
                return false
            }

            val encoderFile = findModelFile(dir, listOf(
                "encoder_model_quantized.onnx", "encoder_model.onnx"
            )) ?: run {
                Log.e(TAG, "No encoder model in $modelDir"); return false
            }
            val decoderFile = findModelFile(dir, listOf(
                "decoder_model_quantized.onnx", "decoder_model.onnx"
            )) ?: run {
                Log.e(TAG, "No plain decoder model in $modelDir"); return false
            }

            val opts = OrtSession.SessionOptions().apply {
                setIntraOpNumThreads(2)
                setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT)
            }

            val encoderSession = getEnvironment().createSession(encoderFile.absolutePath, opts)
            val decoderSession = getEnvironment().createSession(decoderFile.absolutePath, opts)
            val tokenizer = UnigramTokenizer(dir)

            var decoderStart = tokenizer.padTokenId
            val configFile = File(dir, "config.json")
            if (configFile.exists()) {
                readInt(configFile, "decoder_start_token_id")?.let { decoderStart = it }
            }

            sessions[id] = Sessions(encoderSession, decoderSession, tokenizer, decoderStart)
            Log.i(TAG, "Loaded translator $id (decoder=${decoderFile.name}, start=$decoderStart)")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load translator $id", e)
            return false
        }
    }

    private fun findModelFile(dir: File, names: List<String>): File? {
        for (n in names) {
            val f = File(dir, n)
            if (f.exists()) return f
        }
        return null
    }

    private fun readInt(file: File, key: String): Int? {
        return try {
            val m = ("\"$key\"\\s*:\\s*(\\d+)").toRegex().find(file.readText())
            m?.groupValues?.get(1)?.toInt()
        } catch (_: Exception) {
            null
        }
    }

    fun translate(id: String, text: String): String? {
        val s = sessions[id] ?: return null
        try {
            val srcIds = s.tokenizer.encode(text)
            if (srcIds.isEmpty()) return ""
            val srcLen = srcIds.size
            val mask = List(srcLen) { 1L }

            // ---- Encoder ----
            val encInput = OnnxTensor.createTensor(
                getEnvironment(),
                LongBuffer.wrap(srcIds.map { it.toLong() }.toLongArray()),
                longArrayOf(1, srcLen.toLong())
            )
            val encMask = OnnxTensor.createTensor(
                getEnvironment(),
                LongBuffer.wrap(mask.toLongArray()),
                longArrayOf(1, srcLen.toLong())
            )
            val encInputs = hashMapOf<String, OnnxTensor>(
                "input_ids" to encInput,
                "attention_mask" to encMask
            )

            var hidden: FloatArray = FloatArray(0)
            var hiddenDims: LongArray = longArrayOf(1, 0, 0)
            var hiddenOk = false
            val encResult = s.encoder.run(encInputs)
            try {
                val tensor = encResult.get(0) as OnnxTensor
                val info = tensor.info as ai.onnxruntime.TensorInfo
                val shape = info.shape // e.g. [1, seq, dim]
                val total = shape.fold(1L) { acc, v -> acc * v }.toInt()
                val buf: FloatBuffer = tensor.floatBuffer
                hidden = FloatArray(total)
                buf.get(hidden)
                hiddenDims = shape
                hiddenOk = true
            } finally {
                encResult.close()
            }
            if (!hiddenOk) return null
            encInput.close()
            encMask.close()

            // ---- Decoder: greedy, re-feed full sequence each step ----
            val generated = ArrayList<Int>()
            val decIds = ArrayList<Int>()
            decIds.add(s.decoderStartTokenId)
            val maxLen = 96

            for (step in 0 until maxLen) {
                val decInput = OnnxTensor.createTensor(
                    getEnvironment(),
                    LongBuffer.wrap(decIds.map { it.toLong() }.toLongArray()),
                    longArrayOf(1, decIds.size.toLong())
                )
                val decMask = OnnxTensor.createTensor(
                    getEnvironment(),
                    LongBuffer.wrap(mask.toLongArray()),
                    longArrayOf(1, srcLen.toLong())
                )
                val encHidden = OnnxTensor.createTensor(
                    getEnvironment(),
                    hidden,
                    hiddenDims
                )
                val decInputs = hashMapOf<String, OnnxTensor>(
                    "input_ids" to decInput,
                    "encoder_attention_mask" to decMask,
                    "encoder_hidden_states" to encHidden
                )

                var nextToken = -1
                val decResult = s.decoder.run(decInputs)
                try {
                    val logitsTensor = decResult.get(0) as OnnxTensor
                    val logitsShape = (logitsTensor.info as ai.onnxruntime.TensorInfo).shape // [1, seq, vocab]
                    val vocabSize = logitsShape[logitsShape.size - 1].toInt()
                    val seqLen = logitsShape[1].toInt()
                    val buf: FloatBuffer = logitsTensor.floatBuffer
                    val lastStart = (seqLen - 1) * vocabSize
                    var maxIdx = 0
                    var maxVal = Float.NEGATIVE_INFINITY
                    for (i in 0 until vocabSize) {
                        val v = buf.get(lastStart + i)
                        if (v > maxVal) { maxVal = v; maxIdx = i }
                    }
                    nextToken = maxIdx
                } finally {
                    decResult.close()
                }

                decInput.close()
                decMask.close()
                encHidden.close()

                if (nextToken < 0 || nextToken == s.tokenizer.eosTokenId) break
                generated.add(nextToken)
                decIds.add(nextToken)
            }

            return s.tokenizer.decode(generated)
        } catch (e: Exception) {
            Log.e(TAG, "Translation failed", e)
            return null
        }
    }

    fun translateBatch(id: String, texts: Array<String>): Array<String>? =
        texts.map { translate(id, it) ?: "" }.toTypedArray()

    fun destroy(id: String) {
        sessions.remove(id)?.let { it.encoder.close(); it.decoder.close() }
    }

    fun destroyAll() {
        sessions.values.forEach { it.encoder.close(); it.decoder.close() }
        sessions.clear()
    }

    // ============ Unigram tokenizer from tokenizer.json ============

    class UnigramTokenizer(modelDir: File) {
        private val vocab = HashMap<String, Int>()
        private val idToPiece = HashMap<Int, String>()

        var unkTokenId = 1
        var bosTokenId = 0
        var eosTokenId = 0
        var padTokenId = 65000

        init {
            val f = File(modelDir, "tokenizer.json")
            if (f.exists()) parse(f.readText())
        }

        private fun parse(json: String) {
            val vocabStart = json.indexOf("\"vocab\"")
            if (vocabStart < 0) return
            val arrStart = json.indexOf('[', vocabStart)
            if (arrStart < 0) return
            // walk bracket depth to find matching ]
            var depth = 0
            var i = arrStart
            var end = json.length
            while (i < json.length) {
                val c = json[i]
                if (c == '[') depth++
                else if (c == ']') { depth--; if (depth == 0) { end = i + 1; break } }
                i++
            }
            if (end <= arrStart) return
            val arr = json.substring(arrStart, end)
            val entry = Regex("\\[\\s*\"((?:[^\"\\\\]|\\\\.)*)\"\\s*,\\s*[-0-9.eE+]+\\s*]")
            var idx = 0
            for (m in entry.findAll(arr)) {
                val piece = unescape(m.groupValues[1])
                vocab[piece] = idx
                idToPiece[idx] = piece
                idx++
            }
            // special tokens from added_tokens / known pieces
            vocab["<pad>"]?.let { padTokenId = it }
            vocab["<unk>"]?.let { unkTokenId = it }
            vocab["</s>"]?.let { eosTokenId = it; bosTokenId = it }
            vocab["<s>"]?.let { bosTokenId = it }
            if (eosTokenId == 0 && idToPiece.isNotEmpty()) eosTokenId = idToPiece.keys.max()
            Log.d(TAG, "Tokenizer: vocab=${vocab.size}, pad=$padTokenId, eos=$eosTokenId")
        }

        private fun unescape(s: String): String {
            val sb = StringBuilder()
            var i = 0
            while (i < s.length) {
                val c = s[i]
                if (c == '\\' && i + 1 < s.length) {
                    when (s[i + 1]) {
                        'n' -> { sb.append('\n'); i += 2 }
                        't' -> { sb.append('\t'); i += 2 }
                        'r' -> { sb.append('\r'); i += 2 }
                        '"' -> { sb.append('"'); i += 2 }
                        '\\' -> { sb.append('\\'); i += 2 }
                        'u' -> {
                            if (i + 5 < s.length) {
                                try {
                                    val code = s.substring(i + 2, i + 6).toInt(16)
                                    sb.append(code.toChar()); i += 6
                                } catch (_: Exception) { sb.append(s[i + 1]); i += 2 }
                            } else { sb.append(s[i + 1]); i += 2 }
                        }
                        else -> { sb.append(s[i + 1]); i += 2 }
                    }
                } else { sb.append(c); i++ }
            }
            return sb.toString()
        }

        fun encode(text: String): List<Int> {
            if (vocab.isEmpty()) return emptyList()
            val norm = " " + text.trim()
            val out = ArrayList<Int>()
            var pos = 0
            while (pos < norm.length) {
                var best = ""
                var bestLen = 0
                val maxTry = minOf(20, norm.length - pos)
                for (len in maxTry downTo 1) {
                    val sub = norm.substring(pos, pos + len)
                        .replace(" ", "\u2581") // ▁
                    if (vocab.containsKey(sub)) { best = sub; bestLen = len; break }
                }
                if (best.isNotEmpty()) {
                    val id = vocab[best]
                    if (id != null) out.add(id)
                    pos += bestLen
                } else {
                    val ch = norm.substring(pos, pos + 1).replace(" ", "\u2581")
                    out.add(vocab[ch] ?: unkTokenId)
                    pos++
                }
            }
            if (eosTokenId != 0) out.add(eosTokenId)
            return out
        }

        fun decode(ids: List<Int>): String {
            val sb = StringBuilder()
            for (id in ids) {
                var p = idToPiece[id] ?: continue
                if (p == "</s>" || p == "<pad>" || p == "<s>") continue
                p = p.replace("\u2581", " ")
                sb.append(p)
            }
            return sb.toString().trim()
        }
    }
}