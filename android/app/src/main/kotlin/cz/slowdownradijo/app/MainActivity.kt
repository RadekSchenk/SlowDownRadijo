package cz.slowdownradijo.app

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import com.google.common.util.concurrent.ListenableFuture
import cz.slowdownradijo.app.data.spotifySearchUrl
import cz.slowdownradijo.app.home.HomeActions
import cz.slowdownradijo.app.home.HomeScreen
import cz.slowdownradijo.app.home.HomeUi
import cz.slowdownradijo.app.home.SleepTimerOption
import cz.slowdownradijo.app.home.SleepTimerSheet
import cz.slowdownradijo.app.l10n.ProvideAppLanguage
import cz.slowdownradijo.app.player.PlaybackService
import cz.slowdownradijo.app.ui.components.LocalReduceMotion
import cz.slowdownradijo.app.ui.components.systemReducesMotion
import cz.slowdownradijo.app.ui.theme.SlowDownTheme
import kotlinx.coroutines.delay
import java.time.Instant

class MainActivity : ComponentActivity() {
    private var controller: ListenableFuture<MediaController>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
        )
        super.onCreate(savedInstanceState)
        val app = app
        app.startNowPlaying()
        setContent {
            val language by app.language.language.collectAsStateWithLifecycle()
            val onAir by app.nowPlaying.onAir.collectAsStateWithLifecycle()
            val playback by app.radio.state.collectAsStateWithLifecycle()
            val sleepFireAt by app.radio.sleepTimerFireAt.collectAsStateWithLifecycle()
            val now by produceState(Instant.now()) {
                while (true) {
                    delay(1000 - System.currentTimeMillis() % 1000)
                    value = Instant.now()
                }
            }
            var showingSleepTimer by rememberSaveable { mutableStateOf(false) }
            var sleepOption by remember { mutableStateOf<SleepTimerOption?>(null) }
            if (sleepFireAt == null) sleepOption = null

            ProvideAppLanguage(language) {
                CompositionLocalProvider(LocalReduceMotion provides systemReducesMotion()) {
                    SlowDownTheme {
                        HomeScreen(
                            HomeUi(onAir, playback, sleepFireAt, now),
                            HomeActions(
                                togglePlay = { app.radio.togglePlayPause() },
                                openSleepTimer = { showingSleepTimer = true },
                                openSong = { track ->
                                    spotifySearchUrl(track.artist, track.title)?.let {
                                        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(it)))
                                    }
                                },
                            ),
                        )
                        if (showingSleepTimer) {
                            SleepTimerSheet(
                                activeOption = sleepOption,
                                fireAt = sleepFireAt,
                                showEnd = onAir.showEnd,
                                now = now,
                                onSelect = { option ->
                                    val duration = option.duration
                                    val end = onAir.showEnd
                                    when {
                                        duration != null -> app.radio.scheduleSleepTimer(duration)
                                        end != null -> app.radio.scheduleSleepTimer(end)
                                    }
                                    sleepOption = option
                                    showingSleepTimer = false
                                },
                                onCancel = {
                                    app.radio.cancelSleepTimer()
                                    showingSleepTimer = false
                                },
                                onDismiss = { showingSleepTimer = false },
                            )
                        }
                    }
                }
            }
        }
    }

    /** Binds the playback service, so it is there to go foreground when the radio plays. */
    override fun onStart() {
        super.onStart()
        controller = MediaController.Builder(this, SessionToken(this, ComponentName(this, PlaybackService::class.java))).buildAsync()
    }

    override fun onStop() {
        controller?.let(MediaController::releaseFuture)
        controller = null
        super.onStop()
    }
}
