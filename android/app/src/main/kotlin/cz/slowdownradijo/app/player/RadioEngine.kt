package cz.slowdownradijo.app.player

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.annotation.OptIn
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.ForwardingPlayer
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.Duration
import java.time.Instant

/**
 * The live stream, as `RadioPlayerService.swift`: Media3 ExoPlayer, the
 * playback state the UI shows, reconnecting after a dropout (2…30 s
 * back-off, a 20 s deadline on connecting, at once when the network comes
 * back), and the sleep timer. [PlaybackService] puts [sessionPlayer] in a
 * MediaSession for the notification, the lock screen, headphones and cars.
 *
 * Audio focus and unplugged headphones are ExoPlayer's: a call or another
 * app pauses the radio (and a short interruption resumes it), unplugging
 * headphones pauses it.
 *
 * Which stream plays follows [StreamQuality] (MP3 or AAC, by the setting and
 * whether the network is metered); when one keeps failing, reconnects
 * alternate with the other one.
 */
@OptIn(UnstableApi::class)
class RadioEngine(
    private val context: Context,
    private val scope: CoroutineScope,
    private val playerFactory: (Context) -> ExoPlayer = ::defaultPlayer,
    /** The listener's choice in Settings. */
    private val quality: () -> StreamQuality = { StreamQuality.AUTO },
) {
    private val _state = MutableStateFlow<PlaybackState>(PlaybackState.Idle)
    val state: StateFlow<PlaybackState> = _state.asStateFlow()

    /** When the sleep timer pauses the radio; `null` without a timer. */
    private val _sleepTimerFireAt = MutableStateFlow<Instant?>(null)
    val sleepTimerFireAt: StateFlow<Instant?> = _sleepTimerFireAt.asStateFlow()

    var lastPlayTrigger = PlayTrigger.USER
        private set
    var lastStopReason = StopReason.USER
        private set

    val player: ExoPlayer by lazy { playerFactory(context).also { it.addListener(listener) } }

    /** What the session sees: play and pause from the notification, lock screen or headphones go through here. */
    val sessionPlayer: Player by lazy {
        object : ForwardingPlayer(player) {
            override fun play() = this@RadioEngine.play(takeSessionTrigger())
            override fun pause() = this@RadioEngine.pause()
            override fun setPlayWhenReady(playWhenReady: Boolean) =
                if (playWhenReady) play() else pause()
            // A car picking "Živé vysílání" sets its item; the stream is the
            // one item there is, so the engine's own stays.
            override fun setMediaItem(mediaItem: MediaItem) = Unit
            override fun setMediaItem(mediaItem: MediaItem, resetPosition: Boolean) = Unit
            override fun setMediaItem(mediaItem: MediaItem, startPositionMs: Long) = Unit
            override fun setMediaItems(mediaItems: MutableList<MediaItem>) = Unit
            override fun setMediaItems(mediaItems: MutableList<MediaItem>, resetPosition: Boolean) = Unit
            override fun setMediaItems(mediaItems: MutableList<MediaItem>, startIndex: Int, startPositionMs: Long) = Unit
            override fun prepare() = Unit
        }
    }

    /** What the next play through the session counts as: set by the car, else the lock screen. */
    var nextSessionTrigger: PlayTrigger? = null
    private fun takeSessionTrigger() = (nextSessionTrigger ?: PlayTrigger.LOCK_SCREEN).also { nextSessionTrigger = null }

    private var metadata: MediaMetadata = MediaMetadata.Builder().setTitle("Slow Down Rádijo").setArtist("Slow Down Rádijo").build()
    private val handler = Handler(Looper.getMainLooper())
    private var reconnectAttempt = 0
    private var reconnectJob: Job? = null
    private var connectTimeoutJob: Job? = null
    private var sleepTimerJob: Job? = null

    /** The stream playing (or connecting) now; `null` before the first play. */
    var currentStream: LiveStream? = null
        private set
    /** Mobile data or a hotspot, as the system reports it. */
    private var networkMetered = false

    fun togglePlayPause(trigger: PlayTrigger = PlayTrigger.USER) {
        when (_state.value) {
            PlaybackState.Playing -> pause()
            PlaybackState.Connecting -> Unit
            else -> play(trigger)
        }
    }

    fun play(trigger: PlayTrigger = PlayTrigger.USER) {
        lastPlayTrigger = trigger
        cancelReconnect()
        reconnectAttempt = 0
        startPlayback()
    }

    fun pause(reason: StopReason = StopReason.USER) {
        lastStopReason = reason
        // A reconnect scheduled after a dropout must not restart what was just paused.
        cancelReconnect()
        connectTimeoutJob?.cancel()
        player.pause()
        _state.value = PlaybackState.Paused
    }

    /** What the notification and lock screen show; set by the now-playing model. */
    fun updateNowPlaying(title: String, subtitle: String, artworkUri: Uri?) {
        metadata = MediaMetadata.Builder()
            .setTitle(title)
            .setArtist(subtitle)
            .setArtworkUri(artworkUri)
            .setIsPlayable(true)
            .setMediaType(MediaMetadata.MEDIA_TYPE_RADIO_STATION)
            .build()
        // Same stream, new metadata: ExoPlayer updates it without reconnecting.
        if (player.mediaItemCount > 0) player.replaceMediaItem(0, mediaItem())
    }

    // Sleep timer

    fun scheduleSleepTimer(duration: Duration) = scheduleSleepTimer(Instant.now().plus(duration))

    fun scheduleSleepTimer(fireAt: Instant) {
        sleepTimerJob?.cancel()
        val wait = Duration.between(Instant.now(), fireAt)
        if (wait.isNegative || wait.isZero) {
            pause(StopReason.SLEEP_TIMER)
            _sleepTimerFireAt.value = null
            return
        }
        _sleepTimerFireAt.value = fireAt
        sleepTimerJob = scope.launch {
            delay(wait.toMillis())
            pause(StopReason.SLEEP_TIMER)
            _sleepTimerFireAt.value = null
        }
    }

    fun cancelSleepTimer() {
        sleepTimerJob?.cancel()
        sleepTimerJob = null
        _sleepTimerFireAt.value = null
    }

    /** Settings changed the quality: a playing radio moves to the newly chosen stream. */
    fun streamQualityChanged() = restartIfStreamChanged()

    // Stream choice

    /** The setting, for analytics. */
    val streamQuality: StreamQuality get() = quality()

    private val preferredStream: LiveStream get() = quality().stream(networkMetered)

    /**
     * The first reconnect retries the same stream (most drops are the network); from then on
     * every even attempt tries the other one, in case only one of the two mounts is down.
     */
    private val streamForThisAttempt: LiveStream
        get() = if (reconnectAttempt >= 2 && reconnectAttempt % 2 == 0) preferredStream.other else preferredStream

    /** Wi-Fi ↔ mobile data or a new setting while playing: switch to the stream that fits now. */
    private fun restartIfStreamChanged() {
        val playing = _state.value == PlaybackState.Playing || _state.value == PlaybackState.Connecting
        val current = currentStream ?: return
        if (!playing || current == preferredStream) return
        cancelReconnect()
        reconnectAttempt = 0
        startPlayback()
    }

    // Playback

    private fun mediaItem() = MediaItem.Builder()
        .setMediaId("live")
        .setUri((currentStream ?: preferredStream).url)
        .setMediaMetadata(metadata)
        .build()

    /** A fresh connection to the live edge, never stale buffered audio. */
    private fun startPlayback() {
        currentStream = streamForThisAttempt
        enterConnecting()
        player.setMediaItem(mediaItem())
        player.prepare()
        player.play()
    }

    private fun enterConnecting() {
        _state.value = PlaybackState.Connecting
        connectTimeoutJob?.cancel()
        connectTimeoutJob = scope.launch {
            delay(CONNECT_TIMEOUT.toMillis())
            if (_state.value == PlaybackState.Connecting) handleFailure()
        }
    }

    private fun handleFailure() {
        connectTimeoutJob?.cancel()
        player.stop()
        _state.value = PlaybackState.Error
        scheduleReconnect()
    }

    private fun scheduleReconnect() {
        reconnectJob?.cancel()
        reconnectAttempt += 1
        val wait = ReconnectPolicy.delayMillis(reconnectAttempt)
        reconnectJob = scope.launch {
            delay(wait)
            reconnectJob = null
            startPlayback()
        }
    }

    private fun cancelReconnect() {
        reconnectJob?.cancel()
        reconnectJob = null
    }

    /** Back on the network while waiting to reconnect: try now. */
    private fun networkBecameAvailable() {
        val waiting = (_state.value == PlaybackState.Error && reconnectJob != null) || _state.value == PlaybackState.Connecting
        if (waiting) {
            cancelReconnect()
            startPlayback()
        }
    }

    private val listener = object : Player.Listener {
        override fun onIsPlayingChanged(isPlaying: Boolean) {
            if (isPlaying) {
                connectTimeoutJob?.cancel()
                reconnectAttempt = 0
                _state.value = PlaybackState.Playing
            } else if (player.playWhenReady && player.playbackSuppressionReason != Player.PLAYBACK_SUPPRESSION_REASON_NONE) {
                // A short interruption (a notification sound, navigation):
                // ExoPlayer resumes by itself when it is over.
                _state.value = PlaybackState.Paused
            }
        }

        override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {
            if (playWhenReady) return
            val stopReason = when (reason) {
                Player.PLAY_WHEN_READY_CHANGE_REASON_AUDIO_BECOMING_NOISY -> StopReason.HEADPHONES
                Player.PLAY_WHEN_READY_CHANGE_REASON_AUDIO_FOCUS_LOSS -> StopReason.INTERRUPTION
                else -> return
            }
            if (_state.value == PlaybackState.Playing || _state.value == PlaybackState.Connecting) pause(stopReason)
        }

        override fun onPlaybackStateChanged(playbackState: Int) {
            when (playbackState) {
                // A stall mid-stream: ExoPlayer keeps trying; the deadline reconnects.
                Player.STATE_BUFFERING -> if (_state.value == PlaybackState.Playing) enterConnecting()
                // A live stream has no end: the connection closed.
                Player.STATE_ENDED -> if (_state.value == PlaybackState.Playing || _state.value == PlaybackState.Connecting) handleFailure()
            }
        }

        override fun onPlayerError(error: PlaybackException) {
            if (_state.value != PlaybackState.Paused) handleFailure()
        }
    }

    init {
        val connectivity = context.getSystemService(ConnectivityManager::class.java)
        networkMetered = connectivity?.isActiveNetworkMetered ?: false
        runCatching {
            connectivity?.registerDefaultNetworkCallback(object : ConnectivityManager.NetworkCallback() {
                private var hadNetwork = true
                override fun onAvailable(network: Network) {
                    val cameBack = !hadNetwork
                    hadNetwork = true
                    if (cameBack) handler.post { networkBecameAvailable() }
                }

                override fun onLost(network: Network) {
                    hadNetwork = false
                }

                override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) {
                    val metered = !capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED)
                    handler.post {
                        if (metered == networkMetered) return@post
                        networkMetered = metered
                        restartIfStreamChanged()
                    }
                }
            })
        }
    }

    companion object {
        /** The stream the song-on-air metadata is read from: the light AAC one, whatever plays. */
        val STREAM_URL = LiveStream.AAC.url
        val CONNECT_TIMEOUT: Duration = Duration.ofSeconds(20)

        private fun defaultPlayer(context: Context): ExoPlayer = ExoPlayer.Builder(context)
            .setAudioAttributes(
                AudioAttributes.Builder().setUsage(C.USAGE_MEDIA).setContentType(C.AUDIO_CONTENT_TYPE_MUSIC).build(),
                /* handleAudioFocus = */ true,
            )
            .setHandleAudioBecomingNoisy(true)
            .setWakeMode(C.WAKE_MODE_NETWORK)
            .build()
    }
}
