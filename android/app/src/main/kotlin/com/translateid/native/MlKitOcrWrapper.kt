package com.translateid.native

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Rect
import android.util.Log
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
import com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await

/**
 * ML Kit Text Recognition v2 Wrapper for Android
 * 
 * Uses Google Play Services ML Kit (no model download needed)
 * Supports: Latin, Chinese, Japanese, Korean, and auto-detection
 * 
 * Dependency: implementation("com.google.mlkit:text-recognition-v2:16.0.0")
 */
class MlKitOcrWrapper(private val context: Context) {
    companion object {
        private const val TAG = "MlKitOcrWrapper"
    }
    
    private val recognizers = mutableMapOf<String, TextRecognizer>()
    
    /** Get or create recognizer for language */
    private fun getRecognizer(language: String): TextRecognizer {
        return recognizers.getOrPut(language) {
            when (language.lowercase()) {
                "zh", "zh-cn", "zh-tw", "chinese" -> TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
                "ja", "japanese" -> TextRecognition.getClient(JapaneseTextRecognizerOptions.Builder().build())
                "ko", "korean" -> TextRecognition.getClient(KoreanTextRecognizerOptions.Builder().build())
                else -> TextRecognition.getClient(TextRecognizerOptions.Builder().build()) // Latin (EN, ID, etc.)
            }
        }
    }
    
    /** Recognize text from file path */
    suspend fun recognizeFromFile(imagePath: String, language: String = "auto"): OcrResult {
        return withContext(Dispatchers.IO) {
            val inputImage = InputImage.fromFilePath(context, android.net.Uri.parse(imagePath))
            val recognizer = getRecognizer(language)
            val mlKitText = recognizer.process(inputImage).await()
            convertToOcrResult(mlKitText, inputImage)
        }
    }
    
    /** Recognize text from byte array (camera frame) */
    suspend fun recognizeFromBytes(
        imageData: ByteArray,
        width: Int,
        height: Int,
        rotationDegrees: Int = 0,
        language: String = "auto"
    ): OcrResult {
        return withContext(Dispatchers.IO) {
            val inputImage = InputImage.fromByteArray(
                imageData, width, height, rotationDegrees, InputImage.IMAGE_FORMAT_NV21
            )
            val recognizer = getRecognizer(language)
            val mlKitText = recognizer.process(inputImage).await()
            convertToOcrResult(mlKitText, inputImage)
        }
    }
    
    /** Recognize text from Bitmap */
    suspend fun recognizeFromBitmap(bitmap: Bitmap, language: String = "auto"): OcrResult {
        return withContext(Dispatchers.IO) {
            val inputImage = InputImage.fromBitmap(bitmap, 0)
            val recognizer = getRecognizer(language)
            val mlKitText = recognizer.process(inputImage).await()
            convertToOcrResult(mlKitText, inputImage)
        }
    }
    
    private fun convertToOcrResult(mlKitText: com.google.mlkit.vision.text.Text, inputImage: InputImage): OcrResult {
        val blocks = mutableListOf<TextBlock>()
        
        for (block in mlKitText.textBlocks) {
            val cornerPoints = block.cornerPoints?.map { p ->
                Point(p.x.toFloat(), p.y.toFloat())
            } ?: emptyList()
            
            val boundingBox = Rect(
                block.boundingBox.left.toFloat() / inputImage.width,
                block.boundingBox.top.toFloat() / inputImage.height,
                block.boundingBox.right.toFloat() / inputImage.width,
                block.boundingBox.bottom.toFloat() / inputImage.height
            )
            
            blocks.add(TextBlock(
                text = block.text,
                boundingBox = boundingBox,
                cornerPoints = cornerPoints,
                confidence = 1.0, // ML Kit doesn't provide per-block confidence
                language = detectLanguage(block.text)
            ))
        }
        
        return OcrResult(
            text = mlKitText.text,
            blocks = blocks,
            imageSize = Size(inputImage.width.toFloat(), inputImage.height.toFloat()),
            latency = 0 // Not tracked here
        )
    }
    
    private fun detectLanguage(text: String): String {
        // Simple heuristic for EN/ID
        val indonesianWords = setOf("dan", "yang", "untuk", "dengan", "dari", "ke", "di", "pada", "adalah", "ini", "itu", "saya", "kamu", "dia", "kami", "kita", "mereka")
        val words = text.toLowerCase().split("\\W+".toRegex())
        var indonesianCount = 0
        for (w in words) {
            if (indonesianWords.contains(w)) indonesianCount++
        }
        return if (indonesianCount > words.size * 0.15) "id" else "en"
    }
    
    /** Get supported languages */
    fun getSupportedLanguages(): List<String> {
        return listOf("en", "id", "zh", "ja", "ko", "auto")
    }
    
    /** Close all recognizers */
    fun close() {
        recognizers.values.forEach { it.close() }
        recognizers.clear()
    }
    
    // ============ Data Classes ============
    
    data class OcrResult(
        val text: String,
        val blocks: List<TextBlock>,
        val imageSize: Size,
        val latency: Long
    )
    
    data class TextBlock(
        val text: String,
        val boundingBox: Rect,
        val cornerPoints: List<Point>,
        val confidence: Double,
        val language: String
    )
    
    data class Rect(
        val left: Float,
        val top: Float,
        val right: Float,
        val bottom: Float
    ) {
        fun width() = right - left
        fun height() = bottom - top
        fun centerX() = (left + right) / 2
        fun centerY() = (top + bottom) / 2
    }
    
    data class Point(val x: Float, val y: Float)
    
    data class Size(val width: Float, val height: Float)
}