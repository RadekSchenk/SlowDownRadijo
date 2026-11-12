package cz.slowdownradijo.app.player

import android.net.Uri
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import cz.slowdownradijo.app.data.NowPlayingTrack
import cz.slowdownradijo.app.data.Show

/**
 * What Android Auto lists, as `CarPlaySceneDelegate.swift`: one item, the
 * live stream, with the show on air and its photo, and the song when the
 * app vouches for it. Picking it plays the radio; the car's Now Playing
 * screen is the media session's, the same as the lock screen's.
 */
object CarLibrary {
    const val ROOT_ID = "root"
    const val LIVE_ID = "live"

    fun root(): MediaItem = MediaItem.Builder()
        .setMediaId(ROOT_ID)
        .setMediaMetadata(
            MediaMetadata.Builder()
                .setTitle("Slow Down Rádijo")
                .setIsBrowsable(true)
                .setIsPlayable(false)
                .setMediaType(MediaMetadata.MEDIA_TYPE_FOLDER_RADIO_STATIONS)
                .build(),
        )
        .build()

    /** "Živé vysílání", with "Show · Artist – Title" under it. */
    fun live(title: String, show: Show?, track: NowPlayingTrack?, artwork: Uri?): MediaItem {
        val detail = listOfNotNull(show?.displayTitle, track?.let { "${it.artist} – ${it.title}" })
            .joinToString(" · ")
            .ifEmpty { "Slow Down Rádijo" }
        return MediaItem.Builder()
            .setMediaId(LIVE_ID)
            .setMediaMetadata(
                MediaMetadata.Builder()
                    .setTitle(title)
                    .setSubtitle(detail)
                    .setArtist(detail)
                    .setArtworkUri(artwork)
                    .setIsBrowsable(false)
                    .setIsPlayable(true)
                    .setMediaType(MediaMetadata.MEDIA_TYPE_RADIO_STATION)
                    .build(),
            )
            .build()
    }
}
