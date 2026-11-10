package cz.slowdownradijo.app.ui.catalog

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import cz.slowdownradijo.app.R
import cz.slowdownradijo.app.data.ScheduleDay
import cz.slowdownradijo.app.data.SharedImages
import cz.slowdownradijo.app.data.Show
import cz.slowdownradijo.app.l10n.AppLanguage
import cz.slowdownradijo.app.l10n.L10nLogic
import cz.slowdownradijo.app.l10n.LocalAppLanguage
import cz.slowdownradijo.app.ui.theme.Theme

/**
 * Phase 0's one screen: the design system (colours, the heading and text
 * styles) and the shared data (the bundled programme with its photos), so
 * the groundwork can be checked before the real screens arrive.
 */
@Composable
fun ThemeCatalog(days: List<ScheduleDay>, onToggleLanguage: (AppLanguage) -> Unit) {
    val language = LocalAppLanguage.current
    Column(
        Modifier
            .fillMaxSize()
            .background(Theme.background)
            .safeDrawingPadding()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = Theme.Spacing.md, vertical = Theme.Spacing.md),
        verticalArrangement = Arrangement.spacedBy(Theme.Spacing.sm),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Image(
                painterResource(R.drawable.brand_logo), contentDescription = null,
                Modifier.height(36.dp),
            )
            Spacer(Modifier.weight(1f))
            Text(
                language.code.uppercase(),
                style = Theme.Typography.Copy.link,
                color = Theme.textPrimary,
                modifier = Modifier
                    .clip(RoundedCornerShape(Theme.Radius.pill))
                    .background(Theme.hairline(0.12f))
                    .clickable { onToggleLanguage(if (language.isEnglish) AppLanguage.CS else AppLanguage.EN) }
                    .padding(horizontal = 12.dp, vertical = 6.dp),
            )
        }
        Spacer(Modifier.height(Theme.Spacing.sm))
        Text(stringResource(R.string.statsTitle), style = Theme.Typography.Heading.page, color = Theme.textPrimary)
        Text(stringResource(R.string.sleepTimerTitle), style = Theme.Typography.Heading.hero, color = Theme.textPrimary)
        Text(stringResource(R.string.homeProgramHeading), style = Theme.Typography.Heading.section, color = Theme.textPrimary)
        Text(stringResource(R.string.nowPlayingHeading), style = Theme.Typography.Heading.item, color = Theme.textPrimary)
        Text(stringResource(R.string.supportIntro), style = Theme.Typography.Copy.body, color = Theme.mutedText)
        Text(stringResource(R.string.showEndsIn, L10nLogic.remaining(language.isEnglish, 1, 27)), style = Theme.Typography.Copy.label, color = Theme.subtleText)
        Text(stringResource(R.string.showPreviousShows, 3), style = Theme.Typography.Copy.link, color = Theme.textPrimary)

        Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.padding(vertical = Theme.Spacing.sm)) {
            listOf(Theme.liveRed, Theme.sunYellow, Theme.sunOrange, Theme.sunRed, Theme.brandPurple, Theme.gold, Theme.mutedText, Theme.statsCard)
                .forEach { Swatch(it) }
        }
        Box(
            Modifier
                .fillMaxWidth()
                .height(6.dp)
                .clip(RoundedCornerShape(3.dp))
                .background(Theme.accentGradient)
        )

        Spacer(Modifier.height(Theme.Spacing.sm))
        val today = days.firstOrNull { it.weekday == 2 } ?: days.firstOrNull()
        today?.shows?.forEach { ShowRow(it, language.isEnglish) }
    }
}

@Composable
private fun Swatch(color: Color) {
    Box(
        Modifier
            .size(28.dp)
            .clip(CircleShape)
            .background(color)
    )
}

@Composable
private fun ShowRow(show: Show, english: Boolean) {
    Row(
        Modifier
            .fillMaxWidth()
            .padding(vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(show.start, style = Theme.Typography.Copy.label, color = Theme.mutedText, modifier = Modifier.width(48.dp))
        val image = SharedImages.drawable(show.artworkName) ?: SharedImages.drawable(show.hostImageName)
        if (image != null) {
            Image(
                painterResource(image), contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .size(52.dp)
                    .clip(RoundedCornerShape(12.dp)),
            )
        } else {
            Box(
                Modifier
                    .size(52.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(Theme.brandPurple)
            )
        }
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(show.displayTitle, style = Theme.Typography.Heading.item, color = Theme.textPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis)
            val sub = show.hostName ?: show.localizedSummary(english)
            if (sub != null) {
                Text(sub, style = Theme.Typography.Copy.label, color = Theme.subtleText, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}
