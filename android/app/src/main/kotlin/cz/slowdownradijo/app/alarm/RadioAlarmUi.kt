package cz.slowdownradijo.app.alarm

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.WbTwilight
import androidx.compose.foundation.text.InlineTextContent
import androidx.compose.foundation.text.appendInlineContent
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TimeInput
import androidx.compose.material3.TimePickerDefaults
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.Placeholder
import androidx.compose.ui.text.PlaceholderVerticalAlign
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import cz.slowdownradijo.app.R
import cz.slowdownradijo.app.data.Show
import cz.slowdownradijo.app.l10n.L10nLogic
import cz.slowdownradijo.app.l10n.LocalAppLanguage
import cz.slowdownradijo.app.ui.components.PrimaryActionButton
import cz.slowdownradijo.app.ui.components.SecondaryActionButton
import cz.slowdownradijo.app.ui.theme.Theme
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime

private val Sun = Color(0xFFF2C25B)

/** Figma "Budík s rádiem" C1: under "Nastavit časovač vypnutí" — "Budit se rádiem ☀", or "Vzbudí tě rádio · Po–Pá 6:30". */
@Composable
fun RadioAlarmLink(settings: RadioAlarmSettings, onClick: () -> Unit) {
    val english = LocalAppLanguage.current.isEnglish
    val label = if (settings.isOn) stringResource(R.string.alarmRow, alarmSummary(english, settings)) else stringResource(R.string.alarmSet)
    // One text with the sun at its end: on two lines it follows the last word.
    val text = buildAnnotatedString {
        append(label)
        // Non-breaking space and word joiner: the sun never wraps alone.
        append("\u00A0\u00A0\u2060")
        appendInlineContent("sun", "☀")
    }
    val sun = mapOf(
        "sun" to InlineTextContent(Placeholder(17.sp, 17.sp, PlaceholderVerticalAlign.TextCenter)) {
            Icon(Icons.Rounded.WbTwilight, null, tint = if (settings.isOn) Sun else Theme.textPrimary, modifier = Modifier.fillMaxSize())
        },
    )
    Text(text, Modifier.clickable(onClick = onClick), style = Theme.Typography.Copy.link, color = Theme.textPrimary, inlineContent = sun)
}

/** Everything the alarm sheet shows, so screenshot tests can set it. */
data class RadioAlarmSheetUi(
    /** As saved: [RadioAlarmSettings.isOn] says whether it's a new alarm or one to change. */
    val settings: RadioAlarmSettings,
    val canScheduleExact: Boolean,
    val showAt: (Instant) -> Show? = { null },
    val zone: ZoneId = ZoneId.systemDefault(),
    val now: Instant = Instant.now(),
    /** Screenshot tests: the sheet after a change. */
    val initialDraft: RadioAlarmSettings? = null,
)

class RadioAlarmActions(
    val save: (RadioAlarmSettings) -> Unit = {},
    val switchOff: () -> Unit = {},
    val openPermission: () -> Unit = {},
    val test: () -> Unit = {},
)

/**
 * Figma C2 / C3: the time, the days, snooze length, who'll be on air, a test alarm. Nothing applies
 * until "Uložit budík" (new or turned off) / "Uložit změny" (on; enabled only after a change).
 * "Vypnout budík" turns it off and keeps the rest.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RadioAlarmSheet(ui: RadioAlarmSheetUi, actions: RadioAlarmActions, onDismiss: () -> Unit) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = Theme.statsCard,
        shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
    ) {
        RadioAlarmSheetContent(ui, actions)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RadioAlarmSheetContent(ui: RadioAlarmSheetUi, actions: RadioAlarmActions) {
    val english = LocalAppLanguage.current.isEnglish
    val saved = ui.settings
    var settings by remember(saved) { mutableStateOf(ui.initialDraft ?: saved) }
    val hasChanges = !settings.sameAlarm(saved)
    Column(
        Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp)
            .padding(top = 12.dp, bottom = 16.dp)
            .navigationBarsPadding(),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(stringResource(R.string.alarmTitle), style = Theme.Typography.Heading.hero, color = Theme.textPrimary)
            val savedFire = if (saved.isOn) RadioAlarm.nextFire(ui.now, saved, ui.zone) else null
            if (savedFire != null) {
                Text(stringResource(R.string.alarmStatusOn, whenLabel(english, savedFire, ui.now, ui.zone)), style = Theme.Typography.manrope(14f, FontWeight.SemiBold), color = Color(0xFF7FD49B))
            } else {
                Text(stringResource(R.string.alarmIntro), style = Theme.Typography.manrope(14f, FontWeight.SemiBold), color = Theme.mutedText)
            }
        }

        if (!ui.canScheduleExact) {
            Column(
                Modifier.fillMaxWidth().background(Color.White.copy(alpha = 0.06f), RoundedCornerShape(16.dp)).padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text(stringResource(R.string.alarmPermissionTitle), style = Theme.Typography.manrope(16f, FontWeight.ExtraBold), color = Theme.textPrimary)
                Text(stringResource(R.string.alarmPermissionBody), style = Theme.Typography.Copy.body, color = Theme.mutedText)
                SecondaryActionButton(stringResource(R.string.alarmOpenSettings), onClick = actions.openPermission)
            }
        }

        val time = rememberTimePickerState(initialHour = settings.hour, initialMinute = settings.minute, is24Hour = true)
        LaunchedEffect(time.hour, time.minute) {
            if (time.hour != settings.hour || time.minute != settings.minute) settings = settings.copy(hour = time.hour, minute = time.minute)
        }
        Box(Modifier.fillMaxWidth().background(Color.White.copy(alpha = 0.04f), RoundedCornerShape(18.dp)).padding(vertical = 16.dp), contentAlignment = Alignment.Center) {
            TimeInput(
                time,
                colors = TimePickerDefaults.colors(
                    timeSelectorSelectedContainerColor = Color(0xFF3A2F5C),
                    timeSelectorUnselectedContainerColor = Color.White.copy(alpha = 0.06f),
                    timeSelectorSelectedContentColor = Theme.textPrimary,
                    timeSelectorUnselectedContentColor = Theme.textPrimary,
                ),
            )
        }

        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(stringResource(R.string.alarmRepeat), style = Theme.Typography.manrope(13f, FontWeight.Bold), color = Theme.mutedText)
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                for (day in 1..7) {
                    val on = day in settings.weekdays
                    Box(
                        Modifier
                            .weight(1f)
                            .aspectRatio(1f)
                            .background(if (on) Theme.liveRed else Color.White.copy(alpha = 0.06f), CircleShape)
                            .clickable { settings = settings.copy(weekdays = if (on) settings.weekdays - day else settings.weekdays + day) }
                            .semantics { selected = on },
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            L10nLogic.shortDayName(english, day % 7 + 1),
                            style = Theme.Typography.manrope(13f, if (on) FontWeight.ExtraBold else FontWeight.SemiBold),
                            color = if (on) Theme.textPrimary else Theme.mutedText,
                        )
                    }
                }
            }
        }

        Column(Modifier.fillMaxWidth().background(Theme.statsCardRaised, RoundedCornerShape(16.dp)).padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(stringResource(R.string.alarmSnooze), style = Theme.Typography.manrope(15f, FontWeight.Bold), color = Theme.textPrimary)
            Text(stringResource(R.string.alarmSnoozeDescription), style = Theme.Typography.manrope(13f, FontWeight.Normal), color = Theme.mutedText)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                for (minutes in RadioAlarmSettings.SNOOZE_CHOICES) {
                    val on = minutes == settings.snoozeMinutes
                    Box(
                        Modifier
                            .weight(1f)
                            .background(if (on) Color(0xFF3A2F5C) else Color.White.copy(alpha = 0.05f), RoundedCornerShape(10.dp))
                            .clickable { settings = settings.copy(snoozeMinutes = minutes) }
                            .semantics { selected = on }
                            .padding(vertical = 10.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(stringResource(R.string.alarmMinutes, minutes), style = Theme.Typography.manrope(13f, if (on) FontWeight.ExtraBold else FontWeight.SemiBold), color = if (on) Theme.textPrimary else Theme.mutedText)
                    }
                }
            }
        }

        val fire = RadioAlarm.nextFire(ui.now, settings, ui.zone)
        val show = fire?.let(ui.showAt)
        if (fire != null && show != null) {
            Column(
                Modifier.fillMaxWidth().background(Color.White.copy(alpha = 0.04f), RoundedCornerShape(16.dp)).padding(14.dp).semantics(mergeDescendants = true) {},
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Text(stringResource(R.string.alarmWakesYou, whenLabel(english, fire, ui.now, ui.zone)), style = Theme.Typography.manrope(13f, FontWeight.SemiBold), color = Theme.mutedText)
                Text(show.displayTitle, style = Theme.Typography.manrope(16f, FontWeight.ExtraBold), color = Theme.textPrimary)
                show.hostName?.let { Text(it, style = Theme.Typography.manrope(13f, FontWeight.SemiBold), color = Theme.mutedText) }
            }
        }

        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            SecondaryActionButton(stringResource(R.string.alarmTest), onClick = actions.test)
            PrimaryActionButton(
                stringResource(if (saved.isOn) R.string.alarmSaveChanges else R.string.alarmSave),
                enabled = !saved.isOn || hasChanges,
            ) {
                if (!ui.canScheduleExact) actions.openPermission()
                actions.save(settings)
            }
            if (saved.isOn) {
                Box(
                    Modifier
                        .fillMaxWidth()
                        .height(48.dp)
                        .border(1.5.dp, Theme.liveRed, RoundedCornerShape(10.dp))
                        .clickable(onClick = actions.switchOff),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(stringResource(R.string.alarmTurnOff), style = Theme.Typography.Copy.button, color = Color(0xFFFF6B84))
                }
            }
        }
        Text(stringResource(if (saved.isOn) R.string.alarmTurnOffNote else R.string.alarmFootnoteAndroid), style = Theme.Typography.manrope(13f, FontWeight.Normal).copy(lineHeight = 18.sp), color = Theme.subtleText)
    }
}

/** Figma B5 / B6 on the home screen: after the alarm started the radio, or while snoozed. */
@Composable
fun RadioAlarmCard(
    wokeAt: Instant?,
    snoozedUntil: Instant?,
    settings: RadioAlarmSettings,
    canSnooze: Boolean,
    now: Instant,
    zone: ZoneId = ZoneId.systemDefault(),
    onSnooze: () -> Unit,
    onDone: () -> Unit,
    onCancelSnooze: () -> Unit,
    onPlayNow: () -> Unit,
    modifier: Modifier = Modifier,
) {
    when {
        snoozedUntil != null && snoozedUntil.isAfter(now) -> Card(
            stringResource(R.string.alarmSnoozedTitle),
            stringResource(R.string.alarmSnoozedUntil, timeLabel(snoozedUntil, zone)),
            listOf(Color(0xFF3B1F7A), Color(0xFF241C3A)),
            stringResource(R.string.alarmCancel) to onCancelSnooze,
            stringResource(R.string.alarmPlayNow) to onPlayNow,
            modifier,
        )
        wokeAt != null && now.isBefore(wokeAt.plusSeconds(15 * 60)) -> Card(
            stringResource(R.string.alarmGoodMorning),
            stringResource(R.string.alarmPlaying, timeLabel(wokeAt, zone)),
            listOf(Color(0xFFB8541C), Color(0xFF7A1838)),
            if (canSnooze) stringResource(R.string.alarmSnoozeFor, settings.snoozeMinutes) to onSnooze else null,
            stringResource(R.string.alarmDone) to onDone,
            modifier,
        )
    }
}

@Composable
private fun Card(title: String, subtitle: String, colors: List<Color>, primary: Pair<String, () -> Unit>?, secondary: Pair<String, () -> Unit>, modifier: Modifier) {
    Column(
        modifier.fillMaxWidth().background(Brush.horizontalGradient(colors), RoundedCornerShape(20.dp)).padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Icon(Icons.Rounded.WbTwilight, null, tint = Sun, modifier = Modifier.size(18.dp))
            Text(title, style = Theme.Typography.manrope(18f, FontWeight.ExtraBold), color = Theme.textPrimary)
        }
        Text(subtitle, style = Theme.Typography.manrope(14f, FontWeight.SemiBold), color = Color(0xFFFFE6C7))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            primary?.let { Pill(it.first, Color(0xFF1A1430), it.second) }
            Pill(secondary.first, Color.White.copy(alpha = 0.2f), secondary.second)
        }
    }
}

@Composable
private fun Pill(title: String, fill: Color, onClick: () -> Unit) {
    Text(
        title, style = Theme.Typography.manrope(14f, FontWeight.Bold), color = Theme.textPrimary,
        modifier = Modifier.background(fill, CircleShape).clickable(onClick = onClick).padding(horizontal = 16.dp, vertical = 10.dp),
    )
}

/** "Po–Pá 6:30", "každý den 7:00", "jednou 6:30", "Po, St 6:30", as iOS. */
@Composable
fun alarmSummary(english: Boolean, settings: RadioAlarmSettings): String {
    val days = when (settings.weekdays) {
        emptySet<Int>() -> stringResource(R.string.alarmOnce)
        (1..7).toSet() -> stringResource(R.string.alarmEveryDay)
        setOf(1, 2, 3, 4, 5) -> stringResource(R.string.alarmWorkdays)
        setOf(6, 7) -> stringResource(R.string.alarmWeekend)
        else -> settings.weekdays.sorted().joinToString(", ") { L10nLogic.shortDayName(english, it % 7 + 1) }
    }
    return "$days ${settings.hour}:${"%02d".format(settings.minute)}"
}

private fun timeLabel(at: Instant, zone: ZoneId): String {
    val time = at.atZone(zone).toLocalTime()
    return "${time.hour}:${"%02d".format(time.minute)}"
}

/** "Zítra 6:30", "Dnes 6:30", "Po 6:30". */
@Composable
private fun whenLabel(english: Boolean, at: Instant, now: Instant, zone: ZoneId): String {
    val day = at.atZone(zone).toLocalDate()
    val today = ZonedDateTime.ofInstant(now, zone).toLocalDate()
    val label = when (day) {
        today -> stringResource(R.string.alarmToday)
        today.plusDays(1) -> stringResource(R.string.alarmTomorrow)
        else -> L10nLogic.shortDayName(english, day.dayOfWeek.value % 7 + 1)
    }
    return "$label ${timeLabel(at, zone)}"
}
