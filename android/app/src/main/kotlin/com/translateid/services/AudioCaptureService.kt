package com.translateid.services

import android.content.Context
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.concurrent.LinkedBlockingQueue

class AudioCaptureService(
    private val context: Context,
    private val mediaProjection: MediaProjection,
    private val onAudioData: (ByteArray) -> Unit
) {
    private var audioRecord: AudioRecord? = null
    @Volatile private var isRecording = false
    private val scope = CoroutineScope(Dispatchers.IO)
    private val audioQueue = LinkedBlockingQueue<ByteArray>(100)

    fun start() {
        if (isRecording) return

        val sampleRate = 16000
        val channelConfig = AudioFormat.CHANNEL_IN_MONO
        val audioFormat = AudioFormat.ENCODING_PCM_16BIT
        val bufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat) * 4

        val playbackCaptureConfig = AudioPlaybackCaptureConfiguration.Builder(mediaProjection)
            .addMatchingUsage(MediaRecorder.AudioSource.VOICE_COMMUNICATION)
            .addMatchingUsage(MediaRecorder.AudioSource.MIC)
            .build()

        audioRecord = AudioRecord.Builder()
            .setAudioPlaybackCaptureConfig(playbackCaptureConfig)
            .setAudioFormat(
                android.media.AudioFormat.Builder()
                    .setEncoding(audioFormat)
                    .setSampleRate(sampleRate)
                    .setChannelMask(channelConfig)
                    .build()
            )
            .setBufferSizeInBytes(bufferSize)
            .build()

        audioRecord?.startRecording()
        isRecording = true

        scope.launch {
            readAudioLoop()
        }

        scope.launch {
            processAudioChannel()
        }
    }

    private fun readAudioLoop() {
        val buffer = ByteArray(4096)
        while (isRecording) {
            val read = audioRecord?.read(buffer, 0, buffer.size) ?: 0
            if (read > 0) {
                val data = buffer.copyOfRange(0, read)
                try { audioQueue.put(data) } catch (e: InterruptedException) { break }
            } else if (read < 0) {
                Log.e("AudioCapture", "Read error: $read")
            }
        }
    }

    private fun processAudioChannel() {
        while (isRecording) {
            val data = audioQueue.poll()
            if (data != null) {
                onAudioData(data)
            } else {
                Thread.sleep(5) // small yield
            }
        }
    }

    fun stop() {
        isRecording = false
        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null
        audioQueue.clear()
    }
}