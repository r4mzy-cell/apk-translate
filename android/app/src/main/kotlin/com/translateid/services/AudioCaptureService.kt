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
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.launch

class AudioCaptureService(
    private val context: Context,
    private val onAudioData: (ByteArray) -> Unit
) {
    private var audioRecord: AudioRecord? = null
    private var isRecording = false
    private val scope = CoroutineScope(Dispatchers.IO)
    private val audioChannel = Channel<ByteArray>(100)

    fun start() {
        if (isRecording) return

        val sampleRate = 16000
        val channelConfig = AudioFormat.CHANNEL_IN_MONO
        val audioFormat = AudioFormat.ENCODING_PCM_16BIT
        val bufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat) * 4

        val playbackCaptureConfig = AudioPlaybackCaptureConfiguration.Builder(
            MediaProjection.createFromUid(context.applicationContext.packageManager.getPackageUid(context.packageName, 0))
        ).addMatchingUsage(MediaRecorder.AudioSource.VOICE_COMMUNICATION)
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
                audioChannel.send(data)
            } else if (read < 0) {
                Log.e("AudioCapture", "Read error: $read")
            }
        }
    }

    private fun processAudioChannel() {
        for (data in audioChannel) {
            if (!isRecording) break
            onAudioData(data)
        }
    }

    fun stop() {
        isRecording = false
        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null
        audioChannel.close()
    }
}