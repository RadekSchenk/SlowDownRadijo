package cz.slowdownradijo.app.player

import android.app.PendingIntent
import android.content.Intent
import androidx.media3.common.MediaItem
import androidx.media3.session.LibraryResult
import androidx.media3.session.MediaLibraryService
import androidx.media3.session.MediaSession
import com.google.common.collect.ImmutableList
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture
import cz.slowdownradijo.app.MainActivity
import cz.slowdownradijo.app.R
import cz.slowdownradijo.app.app
import cz.slowdownradijo.app.l10n.inLanguage
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.launch

/**
 * The media session: the notification, lock screen controls, headphone
 * buttons, Bluetooth and Android Auto. Media3 keeps the service in the
 * foreground while the radio plays. For the car it is a library of one
 * item, the live stream ([CarLibrary]).
 */
class PlaybackService : MediaLibraryService() {
    private var session: MediaLibrarySession? = null
    private var updates: Job? = null

    override fun onCreate() {
        super.onCreate()
        // In the car the app may never have been opened on the phone.
        app.startNowPlaying()
        val open = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val library = MediaLibrarySession.Builder(this, app.radio.sessionPlayer, Callback())
            .setSessionActivity(open)
            .build()
        session = library
        // The car's list follows the show and the song.
        updates = app.scope.launch {
            app.nowPlaying.onAir.combine(app.language.language) { onAir, language -> Triple(onAir.show?.id, onAir.verifiedTrack, language) }
                .distinctUntilChanged()
                .drop(1)
                .collect { library.notifyChildrenChanged(CarLibrary.ROOT_ID, 1, null) }
        }
    }

    private fun liveItem(): MediaItem {
        val onAir = app.nowPlaying.onAir.value
        val title = inLanguage(app.language.language.value).getString(R.string.carPlayLive)
        return CarLibrary.live(title, onAir.show, onAir.verifiedTrack, app.artworkUri(onAir.show))
    }

    private inner class Callback : MediaLibrarySession.Callback {
        override fun onGetLibraryRoot(
            session: MediaLibrarySession, browser: MediaSession.ControllerInfo, params: LibraryParams?,
        ): ListenableFuture<LibraryResult<MediaItem>> = Futures.immediateFuture(LibraryResult.ofItem(CarLibrary.root(), params))

        override fun onGetChildren(
            session: MediaLibrarySession, browser: MediaSession.ControllerInfo, parentId: String,
            page: Int, pageSize: Int, params: LibraryParams?,
        ): ListenableFuture<LibraryResult<ImmutableList<MediaItem>>> = Futures.immediateFuture(
            if (parentId == CarLibrary.ROOT_ID) LibraryResult.ofItemList(ImmutableList.of(liveItem()), params)
            else LibraryResult.ofError(LibraryResult.RESULT_ERROR_BAD_VALUE),
        )

        override fun onGetItem(
            session: MediaLibrarySession, browser: MediaSession.ControllerInfo, mediaId: String,
        ): ListenableFuture<LibraryResult<MediaItem>> = Futures.immediateFuture(
            when (mediaId) {
                CarLibrary.LIVE_ID -> LibraryResult.ofItem(liveItem(), null)
                CarLibrary.ROOT_ID -> LibraryResult.ofItem(CarLibrary.root(), null)
                else -> LibraryResult.ofError(LibraryResult.RESULT_ERROR_BAD_VALUE)
            },
        )

        /** "Živé vysílání" picked in the car: the session then plays the engine's stream. */
        override fun onAddMediaItems(
            mediaSession: MediaSession, controller: MediaSession.ControllerInfo, mediaItems: MutableList<MediaItem>,
        ): ListenableFuture<MutableList<MediaItem>> {
            app.radio.nextSessionTrigger = PlayTrigger.ANDROID_AUTO
            return Futures.immediateFuture(mutableListOf(liveItem()))
        }
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaLibrarySession? = session

    /** Swiped away from recents while paused: nothing left to do. */
    override fun onTaskRemoved(rootIntent: Intent?) {
        val player = session?.player
        if (player == null || !player.playWhenReady || player.mediaItemCount == 0) stopSelf()
    }

    override fun onDestroy() {
        updates?.cancel()
        // The player belongs to the app's RadioEngine and outlives the session.
        session?.release()
        session = null
        super.onDestroy()
    }
}
