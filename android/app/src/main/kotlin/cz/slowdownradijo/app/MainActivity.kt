package cz.slowdownradijo.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import cz.slowdownradijo.app.l10n.ProvideAppLanguage
import cz.slowdownradijo.app.ui.catalog.ThemeCatalog
import cz.slowdownradijo.app.ui.theme.SlowDownTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
        )
        super.onCreate(savedInstanceState)
        val app = app
        setContent {
            val language by app.language.language.collectAsStateWithLifecycle()
            val days by app.schedule.days.collectAsStateWithLifecycle()
            ProvideAppLanguage(language) {
                SlowDownTheme {
                    ThemeCatalog(days = days, onToggleLanguage = { app.language.set(it) })
                }
            }
        }
    }
}
