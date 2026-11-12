package cz.slowdownradijo.app

import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertTrue
import android.content.ComponentName
import androidx.test.core.app.ApplicationProvider
import cz.slowdownradijo.app.player.PlaybackService
import org.junit.rules.ExternalResource
import org.junit.rules.RuleChain
import org.robolectric.Shadows.shadowOf
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * The real activity, the way a phone starts it: every screen composed in
 * it, not on its own. The emulator found a crash (a permission launcher
 * without an activity behind the language's context) that the screen-by-
 * screen tests could not.
 */
@RunWith(AndroidJUnit4::class)
class MainActivityTest {
    /** Before the activity starts: no autoplay, and no binding to the playback service (Robolectric can't). */
    private val setup = object : ExternalResource() {
        override fun before() {
            val app = ApplicationProvider.getApplicationContext<SlowDownApp>()
            app.settings.setAutoplay(false)
            app.language.set(cz.slowdownradijo.app.l10n.AppLanguage.CS)
            shadowOf(app).declareComponentUnbindable(ComponentName(app, PlaybackService::class.java))
        }
    }
    val compose = createAndroidComposeRule<MainActivity>()

    @get:Rule val rules: RuleChain = RuleChain.outerRule(setup).around(compose)

    @Test fun `starts, and every tab and the menu open`() {
        compose.onNodeWithText("Pořady").assertExists()
        compose.onNodeWithText("Statistiky").performClick()
        compose.waitForIdle()
        compose.onAllNodesWithText("Statistiky").fetchSemanticsNodes().let { assertTrue(it.size >= 2) }
        compose.onNodeWithText("Vzkaz").performClick()
        compose.onNodeWithText("Pošli nám vzkaz").assertExists()
        compose.onNodeWithText("Rádio").performClick()
        compose.onNodeWithText("MENU").performClick()
        compose.onNodeWithText("Nastavení").performClick()
        compose.onNodeWithText("Automatické přehrávání").assertExists()
    }

    /**
     * One page on screen at a time. Pages kept for later used to be drawn
     * under the selected one (seen on the emulator): Statistiky over Rádio.
     * Now only the selected page is composed at all.
     */
    @Test fun `only the selected tab is drawn`() {
        compose.onNodeWithText("Statistiky").performClick()
        compose.waitForIdle()
        compose.onNodeWithText("Pořady").assertDoesNotExist()
        compose.onNodeWithText("Rádio").performClick()
        compose.waitForIdle()
        compose.onNodeWithText("Pořady").assertExists()
    }

    @Test fun `switching the language keeps the activity working`() {
        compose.activity.app.language.set(cz.slowdownradijo.app.l10n.AppLanguage.EN)
        compose.waitForIdle()
        compose.onNodeWithText("Shows").assertExists()
        compose.activity.app.language.set(cz.slowdownradijo.app.l10n.AppLanguage.CS)
    }
}
