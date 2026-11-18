package com.translateid.services

import android.graphics.Bitmap
import android.graphics.ImageFormat
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.util.Log
import android.view.Surface
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.nio.ByteBuffer

class ScreenCaptureService(
    private val mediaProjection: MediaProjection,
    private val mode: String, // "screenshot" or "live"
    private val onFrameCaptured: (Bitmap) -> Unit
) {
    private var imageReader: ImageReader? = null
    private var virtualDisplay: android.hardware.display.VirtualDisplay? = null
    private val scope = CoroutineScope(Dispatchers.IO)

    fun start() {
        scope.launch {
            createVirtualDisplay()
        }
    }

    fun stop() {
        virtualDisplay?.release()
        virtualDisplay = null
        imageReader?.close()
        imageReader = null
    }

    private fun createVirtualDisplay() {
        val width = 1080 // TODO: Get from display metrics
        val height = 1920
        val dpi = 320

        imageReader = ImageReader.newInstance(width, height, ImageFormat.RGB_888, 2)
        imageReader?.setOnImageAvailableListener({ reader ->
            val image = reader.acquireLatestImage() ?: return@setOnImageAvailableListener
            val bitmap = imageToBitmap(image)
            image.close()
            onFrameCaptured(bitmap)
        }, null)

        virtualDisplay = mediaProjection.createVirtualDisplay(
            "ScreenCapture",
            width,
            height,
            dpi,
            0,
            imageReader?.surface,
            null,
            null
        )
    }

    private fun imageToBitmap(image: Image): Bitmap {
        val planes = image.planes
        val width = image.width
        val height = image.height

        val buffer = planes[0].buffer
        val pixelStride = planes[0].pixelStride
        val rowStride = planes[0].rowStride
        val rowPadding = rowStride - pixelStride * width

        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        bitmap.copyPixelsFromBuffer(buffer)

        return bitmap
    }
}