package cz.slowdownradijo.app.home

import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material.icons.rounded.Notifications
import androidx.compose.material.icons.rounded.NotificationsNone
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import cz.slowdownradijo.app.R
import cz.slowdownradijo.app.data.ScheduleDay
import cz.slowdownradijo.app.data.ScheduleStore.Companion.STATION_ZONE
import cz.slowdownradijo.app.data.ScheduleStore.Companion.weekdaySundayFirst
import cz.slowdownradijo.app.data.SharedImages
import cz.slowdownradijo.app.data.Show
import cz.slowdownradijo.app.l10n.L10nLogic
import cz.slowdownradijo.app.l10n.LocalAppLanguage
import cz.slowdownradijo.app.ui.components.ListDivider
import cz.slowdownradijo.app.ui.theme.Theme
import java.time.Instant

/**
 * "Pořady" on the home screen, as `HomeProgramSection.swift`: the next
 * seven days to pick from, then the day's shows with time, reminder bell,
 * title, host, photo and description. On today, the shows already over
 * fold away behind "Zobrazit předchozí pořady".
 */
@Composable
fun HomeProgramSection(
    days: List<ScheduleDay>,
    currentShow: Show?,
    now: Instant,
    followed: Set<String>,
    onBell: (Show) -> Unit,
    modifier: Modifier = Modifier,
) {
    val english = LocalAppLanguage.current.isEnglish
    val today = now.atZone(STATION_ZONE).toLocalDate()
    val todayWeekday = now.atZone(STATION_ZONE).weekdaySundayFirst()
    var selected by rememberSaveable { mutableIntStateOf(todayWeekday) }
    var showingPast by rememberSaveable(selected) { mutableStateOf(false) }

    val shows = days.firstOrNull { it.weekday == selected }?.shows.orEmpty()
    val currentIndex = if (selected == todayWeekday && currentShow != null) {
        shows.indexOfFirst { it.id == currentShow.id && it.start == currentShow.start }.takeIf { it >= 0 }
    } else null
    val past = currentIndex?.let { shows.subList(0, it) }.orEmpty()
    val upcoming = currentIndex?.let { shows.subList(it + 1, shows.size) } ?: shows
    val displayed = if (showingPast) past + upcoming else upcoming

    Column(modifier.animateContentSize()) {
        Column(verticalArrangement = Arrangement.spacedBy(Theme.Spacing.lg)) {
            Text(stringResource(R.string.homeProgramHeading), style = Theme.Typography.Heading.section, color = Theme.textPrimary)
            Row(horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                for (offset in 0L until 7L) {
                    val date = today.plusDays(offset)
                    val weekday = date.atStartOfDay(STATION_ZONE).weekdaySundayFirst()
                    DayChip(
                        label = if (offset == 0L) stringResource(R.string.today) else L10nLogic.shortDayName(english, weekday),
                        day = date.dayOfMonth,
                        isSelected = weekday == selected,
                        modifier = Modifier.weight(1f),
                    ) { selected = weekday }
                }
            }
            ListDivider()
        }

        if (past.isNotEmpty()) {
            PastShowsDisclosure(showingPast, past.size) { showingPast = !showingPast }
            ListDivider()
        }

        if (displayed.isEmpty()) {
            Text(
                stringResource(R.string.noProgramForDay), style = Theme.Typography.manrope(13f, FontWeight.Normal),
                color = Theme.lavender, modifier = Modifier.padding(vertical = Theme.Spacing.md),
            )
        } else {
            displayed.forEachIndexed { index, show ->
                ShowRow(show, english, isFollowing = show.id in followed) { onBell(show) }
                if (index < displayed.size - 1) ListDivider()
            }
        }
    }
}

@Composable
private fun DayChip(label: String, day: Int, isSelected: Boolean, modifier: Modifier, onClick: () -> Unit) {
    Column(
        modifier
            .heightIn(min = 58.dp)
            .clip(RoundedCornerShape(8.dp))
            .background(if (isSelected) Color(0xFF29213F) else Color.Transparent)
            .clickable(role = Role.Tab, onClick = onClick)
            .semantics { selected = isSelected },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            label,
            style = Theme.Typography.manrope(12f, if (isSelected) FontWeight.ExtraBold else FontWeight.Normal),
            color = if (isSelected) Theme.textPrimary else Theme.subtleText, maxLines = 1,
        )
        Text(
            "$day",
            style = Theme.Typography.manrope(22f, if (isSelected) FontWeight.ExtraBold else FontWeight.Light).copy(lineHeight = 28.sp),
            color = if (isSelected) Theme.textPrimary else Color(0xFF807894),
        )
    }
}

@Composable
private fun PastShowsDisclosure(expanded: Boolean, count: Int, onClick: () -> Unit) {
    val rotation by animateFloatAsState(if (expanded) 180f else 0f, label = "chevron")
    Row(
        Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            if (expanded) stringResource(R.string.hidePreviousShows) else stringResource(R.string.showPreviousShows, count),
            style = Theme.Typography.Copy.link, color = Theme.textPrimary, maxLines = 1,
        )
        Spacer(Modifier.weight(1f))
        Icon(Icons.Rounded.KeyboardArrowDown, null, tint = Theme.textPrimary, modifier = Modifier.size(20.dp).rotate(rotation))
    }
}

@Composable
private fun ShowRow(show: Show, english: Boolean, isFollowing: Boolean, onBell: () -> Unit) {
    Column(Modifier.padding(vertical = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        show.start, style = Theme.Typography.manrope(22f, FontWeight.Light).copy(lineHeight = 28.sp),
                        color = Theme.textPrimary,
                    )
                    ReminderBell(show, isFollowing, onBell)
                }
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(show.displayTitle, style = Theme.Typography.Heading.item.copy(lineHeight = 22.sp), color = Theme.textPrimary)
                    show.hostName?.let { Text(it, style = Theme.Typography.Copy.label, color = Theme.textPrimary) }
                }
            }
            ShowArtwork(show, Modifier.size(80.dp).clip(RoundedCornerShape(8.dp)))
        }
        show.localizedSummary(english)?.let {
            Text(it, style = Theme.Typography.Copy.body.copy(lineHeight = 20.sp), color = Theme.mutedText, maxLines = 2)
        }
    }
}

/** The bell after a show's time: red and filled when the show's start is announced (`ReminderBellButton`). */
@Composable
fun ReminderBell(show: Show, isOn: Boolean, onClick: () -> Unit) {
    val label = stringResource(R.string.reminderBellLabel, show.displayTitle)
    Box(
        Modifier
            // A 48 dp touch target around the 19 dp glyph.
            .size(48.dp)
            .clickable(role = Role.Switch, onClick = onClick)
            .semantics { contentDescription = label; selected = isOn },
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            if (isOn) Icons.Rounded.Notifications else Icons.Rounded.NotificationsNone, null,
            tint = if (isOn) Theme.liveRed else Theme.mutedText, modifier = Modifier.size(19.dp),
        )
    }
}

/** The show's bundled photo, else its photo from the web, else the brand placeholder (`ShowArtworkView`). */
@Composable
fun ShowArtwork(show: Show, modifier: Modifier) {
    val bundled = SharedImages.drawable(show.artworkName)
    when {
        bundled != null -> Image(painterResource(bundled), null, modifier, contentScale = ContentScale.Crop)
        show.imageURL != null -> AsyncImage(show.imageURL, null, modifier.background(Theme.brandPurple), contentScale = ContentScale.Crop)
        else -> ShowArtworkPlaceholder(modifier)
    }
}
