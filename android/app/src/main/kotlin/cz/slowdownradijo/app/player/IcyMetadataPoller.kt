package cz.slowdownradijo.app.player

import cz.slowdownradijo.app.data.NowPlayingTrack
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
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.EOFException
import java.io.InputStream
import java.nio.ByteBuffer
import java.nio.charset.CharacterCodingException
import java.nio.charset.CodingErrorAction
import java.time.Duration

/**
 * Reads the stream's ICY `StreamTitle` every [interval], as
 * `ICYMetadataService.swift`: a short request with `Icy-MetaData: 1`, skip
 * `icy-metaint` audio bytes, read one metadata block, hang up. Independent
 * of the player, so the song is known whether the radio plays or not.
 */
class IcyMetadataPoller(
    private val client: OkHttpClient,
    private val streamUrl: String = RadioEngine.STREAM_URL,
    private val interval: Duration = Duration.ofSeconds(20),
) {
    private val _track = MutableStateFlow<NowPlayingTrack?>(null)
    val track: StateFlow<NowPlayingTrack?> = _track.asStateFlow()
    private var job: Job? = null

    fun start(scope: CoroutineScope) {
        if (job?.isActive == true) return
        job = scope.launch {
            while (isActive) {
                runCatching { pollOnce() }.getOrNull()?.let { _track.value = it }
                delay(interval.toMillis())
            }
        }
    }

    fun stop() {
        job?.cancel()
        job = null
    }

    /** One read; `null` when the server has no title this cycle. */
    suspend fun pollOnce(): NowPlayingTrack? = withContext(Dispatchers.IO) {
        val request = Request.Builder().url(streamUrl).header("Icy-MetaData", "1").build()
        client.newCall(request).execute().use { response ->
            val metaInt = response.header("icy-metaint")?.toIntOrNull()?.takeIf { it > 0 } ?: return@use null
            readStreamTitle(response.body.byteStream(), metaInt)?.let(NowPlayingTrack::parse)
        }
    }

    companion object {
        /** Skips [metaInt] audio bytes, then reads the metadata block's `StreamTitle`. */
        fun readStreamTitle(input: InputStream, metaInt: Int): String? {
            var skip = metaInt.toLong()
            val scratch = ByteArray(8192)
            while (skip > 0) {
                val read = input.read(scratch, 0, minOf(scratch.size.toLong(), skip).toInt())
                if (read < 0) throw EOFException()
                skip -= read
            }
            val lengthByte = input.read()
            if (lengthByte < 0) throw EOFException()
            val length = lengthByte * 16
            if (length == 0) return null // no metadata change this cycle
            val block = ByteArray(length)
            var offset = 0
            while (offset < length) {
                val read = input.read(block, offset, length - offset)
                if (read < 0) throw EOFException()
                offset += read
            }
            return streamTitle(decode(block))
        }

        /** UTF-8, else Latin-1, as on iOS. */
        private fun decode(bytes: ByteArray): String = try {
            Charsets.UTF_8.newDecoder()
                .onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT)
                .decode(ByteBuffer.wrap(bytes)).toString()
        } catch (_: CharacterCodingException) {
            String(bytes, Charsets.ISO_8859_1)
        }

        fun streamTitle(raw: String): String? {
            val start = raw.indexOf("StreamTitle='").takeIf { it >= 0 }?.plus("StreamTitle='".length) ?: return null
            val end = raw.indexOf("';", start).takeIf { it >= 0 } ?: return null
            return raw.substring(start, end)
        }
    }
}
