package cz.slowdownradijo.app.player

import android.net.Uri
import cz.slowdownradijo.app.data.NowPlayingTrack
import cz.slowdownradijo.app.data.Show
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class CarLibraryTest {
    private val show = Show("majkl", "Show podle Majkla s Vrtulníkem", "13:00", "14:00", title = "Show podle Majkla")

    @Test fun `the root is a folder with one playable live item`() {
        val root = CarLibrary.root().mediaMetadata
        assertTrue(root.isBrowsable == true)
        assertFalse(root.isPlayable == true)
    }

    @Test fun `the live item names the show and, when vouched for, the song`() {
        val art = Uri.parse("android.resource://cz.slowdownradijo.app/drawable/show_art")
        val item = CarLibrary.live("Živé vysílání", show, NowPlayingTrack("Khruangbin", "Maria También"), art)
        assertEquals(CarLibrary.LIVE_ID, item.mediaId)
        assertEquals("Živé vysílání", item.mediaMetadata.title)
        assertEquals("Show podle Majkla · Khruangbin – Maria También", item.mediaMetadata.subtitle)
        assertEquals(art, item.mediaMetadata.artworkUri)
        assertTrue(item.mediaMetadata.isPlayable == true)
        assertEquals("Show podle Majkla", CarLibrary.live("Živé vysílání", show, null, null).mediaMetadata.subtitle)
        assertEquals("Slow Down Rádijo", CarLibrary.live("Live", null, null, null).mediaMetadata.subtitle)
    }
}
