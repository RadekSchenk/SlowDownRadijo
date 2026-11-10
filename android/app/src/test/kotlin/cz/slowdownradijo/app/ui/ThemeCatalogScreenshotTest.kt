package cz.slowdownradijo.app.ui

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.github.takahirom.roborazzi.RobolectricDeviceQualifiers
import com.github.takahirom.roborazzi.captureRoboImage
import cz.slowdownradijo.app.data.ScheduleStore
import cz.slowdownradijo.app.l10n.AppLanguage
import cz.slowdownradijo.app.l10n.ProvideAppLanguage
import cz.slowdownradijo.app.ui.catalog.ThemeCatalog
import cz.slowdownradijo.app.ui.theme.SlowDownTheme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = RobolectricDeviceQualifiers.Pixel7)
class ThemeCatalogScreenshotTest {
    @get:Rule val compose = createComposeRule()

    private fun capture(language: AppLanguage) {
        val days = ScheduleStore.bundled(ApplicationProvider.getApplicationContext())
        compose.setContent {
            ProvideAppLanguage(language) {
                SlowDownTheme { ThemeCatalog(days = days, onToggleLanguage = {}) }
            }
        }
        compose.onRoot().captureRoboImage("src/test/screenshots/theme_catalog_${language.code}.png")
    }

    @Test fun czech() = capture(AppLanguage.CS)

    @Test fun english() = capture(AppLanguage.EN)
}
