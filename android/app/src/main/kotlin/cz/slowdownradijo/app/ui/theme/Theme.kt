package cz.slowdownradijo.app.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import cz.slowdownradijo.app.R

/**
 * The design system, the same as the iOS app's
 * `SlowDownRadijo/DesignSystem/Theme.swift` (keep the two in step). The app
 * is dark only.
 */
object Theme {
    // Backgrounds
    val background = Color(0xFF120E25)
    val surface = Color(0xFF1A1A1E)
    val surfaceElevated = Color(0xFF222226)
    val tabBarBackground = Color(0xFF1A1535)
    val mutedText = Color(0xFFB8AFDC)
    val subtleText = Color(0xFFA699B8)
    val divider = Color(0xFF332B4D)
    val statsCard = Color(0xFF1A1535)
    val statsCardRaised = Color(0xFF241C3A)
    val statsBarMuted = Color(0xFF665781)
    val tabBarUnselected = mutedText

    // Brand
    val brandPurple = Color(0xFF433785)
    val sunYellow = Color(0xFFFAB817)
    val sunOrange = Color(0xFFE8652B)
    val sunRed = Color(0xFFE04A4F)
    val liveRed = Color(0xFFDB304E)
    val waveformMuted = Color(0xFF2A263B)
    val equalizerUnplayed = Color(0xFFB8AFDC)
    val lavender = Color(0xFF8F89A9)
    val gold = Color(0xFFD4A24C)
    val purpleAccent = Color(0xFFA78BFA)
    val spotifyGreen = Color(0xFF00CA47)

    val accentGradient = Brush.horizontalGradient(listOf(sunYellow, sunOrange, sunRed))
    val accentGradientVertical = Brush.verticalGradient(listOf(sunYellow, sunOrange, sunRed))

    // Text
    val textPrimary = Color(0xFFFFFFFF)
    val textSecondary = Color.White.copy(alpha = 0.6f)
    val textTertiary = Color.White.copy(alpha = 0.4f)

    // Status
    val statusError = Color(0xFFE04A4F)
    val statusLive = Color(0xFFFAB817)

    /** Faint hairline overlay: white at the given opacity. */
    fun hairline(opacity: Float) = Color.White.copy(alpha = opacity)

    object Spacing {
        val xs = 4.dp
        val sm = 8.dp
        val md = 16.dp
        val lg = 24.dp
        val xl = 32.dp
        val xxl = 48.dp
    }

    object Radius {
        val card = 20.dp
        val button = 16.dp
        val pill = 100.dp
    }

    /** Bottom navigation, as `RootTabView` on iOS. */
    object TabBar {
        val iconSize = 22.dp
        val labelSize = 11.sp
        val topPadding = 10.dp
        val iconLabelSpacing = 6.dp
    }

    object Typography {
        /** Manrope for every text in the app, from the iOS Resources/Fonts. */
        val manrope = FontFamily(
            Font(R.font.manrope_light, FontWeight.Light),
            Font(R.font.manrope_regular, FontWeight.Normal),
            Font(R.font.manrope_medium, FontWeight.Medium),
            Font(R.font.manrope_semibold, FontWeight.SemiBold),
            Font(R.font.manrope_bold, FontWeight.Bold),
            Font(R.font.manrope_extrabold, FontWeight.ExtraBold),
        )

        fun manrope(size: Float, weight: FontWeight) = TextStyle(
            fontFamily = manrope,
            fontWeight = weight,
            fontSize = size.sp,
        )

        /**
         * The four heading levels, all Manrope ExtraBold:
         * `page` 24 (a screen's title), `hero` 21 (the one big title of a
         * sheet or card), `section` 19 (a section in a screen), `item` 17
         * (an entry in a list).
         */
        object Heading {
            val page = manrope(24f, FontWeight.ExtraBold)
            val hero = manrope(21f, FontWeight.ExtraBold)
            val section = manrope(19f, FontWeight.ExtraBold)
            val item = manrope(17f, FontWeight.ExtraBold)
        }

        /**
         * Text under the headings: `body` 14 SemiBold, `reading` 16 Regular
         * (long reading and typing), `label` 13 SemiBold, `link` 14 Bold,
         * `button` 15 ExtraBold.
         */
        object Copy {
            val body = manrope(14f, FontWeight.SemiBold)
            val reading = manrope(16f, FontWeight.Normal)
            val label = manrope(13f, FontWeight.SemiBold)
            val link = manrope(14f, FontWeight.Bold)
            val button = manrope(15f, FontWeight.ExtraBold)
        }
    }
}

private val colorScheme = darkColorScheme(
    primary = Theme.liveRed,
    onPrimary = Theme.textPrimary,
    secondary = Theme.brandPurple,
    background = Theme.background,
    onBackground = Theme.textPrimary,
    surface = Theme.background,
    onSurface = Theme.textPrimary,
    surfaceVariant = Theme.statsCard,
    onSurfaceVariant = Theme.mutedText,
    outline = Theme.divider,
    error = Theme.statusError,
)

@Composable
fun SlowDownTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = colorScheme,
        typography = MaterialTheme.typography.run {
            copy(
                bodyLarge = Theme.Typography.Copy.reading,
                bodyMedium = Theme.Typography.Copy.body,
                labelMedium = Theme.Typography.Copy.label,
                titleLarge = Theme.Typography.Heading.page,
            )
        },
        content = content,
    )
}
