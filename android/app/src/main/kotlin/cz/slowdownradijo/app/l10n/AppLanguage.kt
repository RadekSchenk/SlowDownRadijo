package cz.slowdownradijo.app.l10n

import android.content.Context
import android.content.ContextWrapper
import android.content.res.AssetManager
import android.content.res.Resources
import android.content.res.Configuration
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.Locale

/**
 * The app's two languages, picked in the app and independent of the
 * phone's, as `LocalizationManager.swift`: Czech for Czech and Slovak
 * phones, English for everyone else, until the listener switches.
 */
enum class AppLanguage(val code: String) {
    CS("cs"), EN("en");

    val isEnglish get() = this == EN
    val locale: Locale get() = Locale.forLanguageTag(code)

    companion object {
        fun fromSystem(locale: Locale = Locale.getDefault()): AppLanguage =
            if (locale.language == "cs" || locale.language == "sk") CS else EN
    }
}

class LanguageStore(context: Context) {
    private val prefs = context.getSharedPreferences("settings", Context.MODE_PRIVATE)
    private val _language = MutableStateFlow(
        prefs.getString(KEY, null)?.let { saved -> AppLanguage.entries.firstOrNull { it.code == saved } }
            ?: AppLanguage.fromSystem()
    )
    val language: StateFlow<AppLanguage> = _language.asStateFlow()

    fun set(language: AppLanguage) {
        prefs.edit().putString(KEY, language.code).apply()
        _language.value = language
    }

    private companion object {
        const val KEY = "app.language"
    }
}

/** [base] with its resources in [language], for text outside Compose (notifications). */
fun Context.inLanguage(language: AppLanguage): Context {
    val config = Configuration(resources.configuration).apply { setLocale(language.locale) }
    return createConfigurationContext(config)
}

val LocalAppLanguage = staticCompositionLocalOf { AppLanguage.CS }

/**
 * [base] itself (an Activity stays reachable through it, which permission
 * dialogs, back handling and media need), only with its resources in
 * [language].
 */
private class LanguageContext(base: Context, language: AppLanguage) : ContextWrapper(base) {
    private val localized = base.inLanguage(language)
    override fun getResources(): Resources = localized.resources
    override fun getAssets(): AssetManager = localized.assets
}

/** Content whose `stringResource` reads [language], switched without a restart. */
@Composable
fun ProvideAppLanguage(language: AppLanguage, content: @Composable () -> Unit) {
    val base = LocalContext.current
    val context: Context = remember(base, language) { LanguageContext(base, language) }
    CompositionLocalProvider(
        LocalContext provides context,
        LocalConfiguration provides context.resources.configuration,
        LocalAppLanguage provides language,
        content = content,
    )
}
