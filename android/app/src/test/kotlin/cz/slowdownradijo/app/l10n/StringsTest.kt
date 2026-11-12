package cz.slowdownradijo.app.l10n

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import cz.slowdownradijo.app.R
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class StringsTest {
    private val context: Context = ApplicationProvider.getApplicationContext()

    @Test fun `strings come in the app's language, not the phone's`() {
        assertEquals("Právě hraje", context.inLanguage(AppLanguage.CS).getString(R.string.nowPlayingHeading))
        assertEquals("Now playing", context.inLanguage(AppLanguage.EN).getString(R.string.nowPlayingHeading))
    }

    @Test fun `placeholders keep their order per language`() {
        assertEquals("Po v 9:00", context.inLanguage(AppLanguage.CS).getString(R.string.nextAiring, "Po", "9:00"))
        assertEquals("Mo at 9:00", context.inLanguage(AppLanguage.EN).getString(R.string.nextAiring, "Mo", "9:00"))
        assertEquals("Zobrazit předchozí pořady (3)", context.inLanguage(AppLanguage.CS).getString(R.string.showPreviousShows, 3))
    }

    @Test fun `Android text replaces the iOS one`() {
        assertEquals(
            "Notifications are turned off for the app in Android settings.",
            context.inLanguage(AppLanguage.EN).getString(R.string.notificationsBlockedToast),
        )
    }

    @Test fun `system language picks Czech for Czech and Slovak phones`() {
        assertEquals(AppLanguage.CS, AppLanguage.fromSystem(java.util.Locale.forLanguageTag("sk-SK")))
        assertEquals(AppLanguage.EN, AppLanguage.fromSystem(java.util.Locale.GERMANY))
    }
}
