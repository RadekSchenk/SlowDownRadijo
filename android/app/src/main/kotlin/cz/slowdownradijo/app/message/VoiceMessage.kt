package cz.slowdownradijo.app.message

import android.content.Context
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.os.Build
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.asRequestBody
import java.io.File
import java.io.IOException
import java.util.UUID
import kotlin.math.log10

sealed interface VoiceMessageState {
    data object Ready : VoiceMessageState
    data object Recording : VoiceMessageState
    data class Recorded(val file: File, val seconds: Double) : VoiceMessageState
    data class Sending(val file: File, val seconds: Double) : VoiceMessageState
    data object Sent : VoiceMessageState
}

/** Posts the recording to the `send-voice-message` function, as `VoiceMessageUploadService.swift`. */
class VoiceMessageUploader(private val client: OkHttpClient, private val endpoint: String = ENDPOINT) {
    suspend fun upload(file: File) = withContext(Dispatchers.IO) {
        val body = MultipartBody.Builder().setType(MultipartBody.FORM)
            .addFormDataPart("audio", file.name, file.asRequestBody("audio/m4a".toMediaType()))
            .build()
        client.newCall(Request.Builder().url(endpoint).post(body).build()).execute().use {
            if (!it.isSuccessful) throw IOException("send-voice-message: ${it.code}")
        }
    }

    companion object {
        const val ENDPOINT = "https://toqoqrshyutyezoyxvlj.supabase.co/functions/v1/send-voice-message"
    }
}

/**
 * The voice message for the studio, as `VoiceMessageViewModel.swift` and
 * `VoiceMessageRecorder.swift`: at most a minute of AAC in MPEG-4 (the
 * .m4a the server checks for), 18 waveform segments from the microphone's
 * level, a preview, and sending. The radio pauses while recording.
 */
class VoiceMessage(
    private val context: Context,
    private val scope: CoroutineScope,
    private val uploader: VoiceMessageUploader,
    private val pauseRadio: () -> Unit,
    private val onSent: (success: Boolean, seconds: Int) -> Unit = { _, _ -> },
) {
    private val _state = MutableStateFlow<VoiceMessageState>(VoiceMessageState.Ready)
    val state: StateFlow<VoiceMessageState> = _state.asStateFlow()
    private val _elapsed = MutableStateFlow(0.0)
    val elapsed: StateFlow<Double> = _elapsed.asStateFlow()
    private val _levels = MutableStateFlow(List(SEGMENTS) { 0f })
    val levels: StateFlow<List<Float>> = _levels.asStateFlow()
    private val _isPlaying = MutableStateFlow(false)
    val isPlaying: StateFlow<Boolean> = _isPlaying.asStateFlow()
    private val _playbackProgress = MutableStateFlow(0.0)
    val playbackProgress: StateFlow<Double> = _playbackProgress.asStateFlow()
    private val _uploadFailed = MutableStateFlow(false)
    val uploadFailed: StateFlow<Boolean> = _uploadFailed.asStateFlow()

    private var recorder: MediaRecorder? = null
    private var file: File? = null
    private var ticker: Job? = null
    private var player: MediaPlayer? = null
    private var playbackJob: Job? = null

    /** Call once the microphone permission is granted. */
    fun startRecording() {
        pauseRadio()
        val target = File(context.cacheDir, "${UUID.randomUUID()}.m4a")
        val newRecorder = (if (Build.VERSION.SDK_INT >= 31) MediaRecorder(context) else @Suppress("DEPRECATION") MediaRecorder()).apply {
            setAudioSource(MediaRecorder.AudioSource.MIC)
            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            setAudioSamplingRate(44_100)
            setAudioChannels(1)
            setAudioEncodingBitRate(96_000)
            setOutputFile(target.absolutePath)
        }
        try {
            newRecorder.prepare()
            newRecorder.start()
        } catch (_: Exception) {
            newRecorder.release()
            _state.value = VoiceMessageState.Ready
            return
        }
        recorder = newRecorder
        file = target
        _elapsed.value = 0.0
        _levels.value = List(SEGMENTS) { 0f }
        _state.value = VoiceMessageState.Recording
        ticker = scope.launch {
            while (isActive) {
                delay(100)
                tick()
            }
        }
    }

    private fun tick() {
        val rec = recorder ?: return
        _elapsed.value += 0.1
        val level = normalizedLevel(runCatching { rec.maxAmplitude }.getOrDefault(0))
        val index = minOf((minOf(_elapsed.value / MAX_SECONDS, 1.0) * SEGMENTS).toInt(), SEGMENTS - 1)
        _levels.value = _levels.value.toMutableList().also { it[index] = maxOf(it[index], level) }
        if (_elapsed.value >= MAX_SECONDS) stopRecording()
    }

    fun stopRecording() {
        val result = finishRecorder() ?: return
        _state.value = VoiceMessageState.Recorded(result.first, result.second)
    }

    private fun finishRecorder(): Pair<File, Double>? {
        val rec = recorder ?: return null
        ticker?.cancel()
        runCatching { rec.stop() }
        rec.release()
        recorder = null
        return file?.let { it to _elapsed.value }
    }

    fun cancelRecording() {
        finishRecorder()?.first?.delete()
        _state.value = VoiceMessageState.Ready
    }

    fun discardRecording() {
        val recorded = _state.value as? VoiceMessageState.Recorded ?: return
        stopPlayback()
        recorded.file.delete()
        _state.value = VoiceMessageState.Ready
    }

    /** "Nahrát znovu": the old take goes, a new one starts. */
    fun retry() {
        stopPlayback()
        (_state.value as? VoiceMessageState.Recorded)?.file?.delete()
        startRecording()
    }

    fun togglePlayback() {
        if (_isPlaying.value) return stopPlayback()
        val recorded = _state.value as? VoiceMessageState.Recorded ?: return
        val newPlayer = runCatching {
            MediaPlayer().apply {
                setDataSource(recorded.file.absolutePath)
                prepare()
                setOnCompletionListener { stopPlayback() }
                start()
            }
        }.getOrNull() ?: return
        player = newPlayer
        _isPlaying.value = true
        playbackJob = scope.launch {
            while (isActive) {
                val p = player ?: break
                _playbackProgress.value = if (p.duration > 0) p.currentPosition.toDouble() / p.duration else 0.0
                delay(50)
            }
        }
    }

    fun stopPlayback() {
        playbackJob?.cancel()
        player?.release()
        player = null
        _isPlaying.value = false
        _playbackProgress.value = 0.0
    }

    fun submit() {
        val recorded = _state.value as? VoiceMessageState.Recorded ?: return
        stopPlayback()
        _state.value = VoiceMessageState.Sending(recorded.file, recorded.seconds)
        scope.launch {
            try {
                uploader.upload(recorded.file)
                recorded.file.delete()
                _state.value = VoiceMessageState.Sent
                onSent(true, recorded.seconds.toInt())
            } catch (_: Exception) {
                onSent(false, recorded.seconds.toInt())
                _uploadFailed.value = true
                _state.value = recorded
            }
        }
    }

    fun dismissUploadFailed() {
        _uploadFailed.value = false
    }

    fun recordAnother() {
        _state.value = VoiceMessageState.Ready
    }

    companion object {
        const val MAX_SECONDS = 60.0
        const val SEGMENTS = 18

        /** MediaRecorder's 0…32767 amplitude in dB, -50…0 dB onto 0…1, as on iOS. */
        fun normalizedLevel(amplitude: Int): Float {
            if (amplitude <= 0) return 0f
            val db = 20 * log10(amplitude / 32767.0)
            return ((maxOf(db, -50.0) + 50) / 50).toFloat()
        }
    }
}
