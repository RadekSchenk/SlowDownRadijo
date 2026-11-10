package cz.slowdownradijo.app.menu

import android.content.Intent
import android.net.Uri
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.NotificationsOff
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.clickable
import cz.slowdownradijo.app.BuildConfig
import cz.slowdownradijo.app.R
import cz.slowdownradijo.app.data.Show
import cz.slowdownradijo.app.l10n.L10nLogic
import cz.slowdownradijo.app.l10n.LocalAppLanguage
import cz.slowdownradijo.app.reminders.openNotificationSettings
import cz.slowdownradijo.app.ui.components.AppSwitch
import cz.slowdownradijo.app.ui.components.BackHeader
import cz.slowdownradijo.app.ui.components.ListDivider
import cz.slowdownradijo.app.ui.components.ListRow
import cz.slowdownradijo.app.ui.components.ListRowChevron
import cz.slowdownradijo.app.ui.components.SecondaryActionButton
import cz.slowdownradijo.app.ui.theme.Theme
import kotlinx.coroutines.launch

/** Everything Settings shows and changes, so screenshot tests can set it. */
data class SettingsUi(
    val autoplay: Boolean,
    val remindersCount: Int,
    val statsEnabled: Boolean,
    val analyticsEnabled: Boolean,
)

class SettingsActions(
    val setAutoplay: (Boolean) -> Unit = {},
    val setStats: (Boolean) -> Unit = {},
    val setAnalytics: (Boolean) -> Unit = {},
    /** Deletes the listening stats; reports success. */
    val deleteStats: suspend () -> Boolean = { true },
)

private const val PRIVACY_POLICY = "https://slowdownradijo.cz/ochrana-osobnich-udaju/"

/** Settings (`SettingsView.swift`). */
@Composable
fun SettingsScreen(ui: SettingsUi, actions: SettingsActions, open: (MenuPage) -> Unit, back: () -> Unit) {
    val english = LocalAppLanguage.current.isEnglish
    val context = LocalContext.current
    var confirmingDeletion by remember { mutableStateOf(false) }
    var result by remember { mutableStateOf<Pair<String, String?>?>(null) }
    val scope = androidx.compose.runtime.rememberCoroutineScope()

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp)
            .padding(top = 20.dp, bottom = Theme.Spacing.xl),
        verticalArrangement = Arrangement.spacedBy(Theme.Spacing.lg),
    ) {
        BackHeader(stringResource(R.string.settingsTitle), stringResource(R.string.close), back)
        Column {
            ListDivider()
            ListRow(stringResource(R.string.settingsAutoplayTitle), stringResource(R.string.settingsAutoplayDescription)) {
                AppSwitch(ui.autoplay, actions.setAutoplay)
            }
            ListDivider()
            ListRow(
                stringResource(R.string.showRemindersTitle), L10nLogic.showRemindersSummary(english, ui.remindersCount),
                onClick = { open(MenuPage.ShowReminders) },
            ) { ListRowChevron() }
            ListDivider()
            ListRow(stringResource(R.string.settingsStatsTitle), stringResource(R.string.settingsStatsDescription)) {
                AppSwitch(ui.statsEnabled, actions.setStats)
            }
            ListDivider()
            ListRow(stringResource(R.string.settingsAnalyticsTitle), stringResource(R.string.settingsAnalyticsDescription)) {
                AppSwitch(ui.analyticsEnabled, actions.setAnalytics)
            }
            ListDivider()
            ListRow(
                stringResource(R.string.settingsStatsDeleteTitle), stringResource(R.string.settingsStatsDeleteDescription),
                onClick = { confirmingDeletion = true },
            )
            ListDivider()
            ListRow(stringResource(R.string.settingsPrivacyPolicy), onClick = {
                runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(PRIVACY_POLICY))) }
            }) { ListRowChevron() }
            ListDivider()
        }
        Text(
            stringResource(R.string.settingsAbout, BuildConfig.VERSION_NAME, BuildConfig.VERSION_CODE.toString()),
            style = Theme.Typography.manrope(14f, FontWeight.Normal), color = Theme.subtleText,
        )
    }

    if (confirmingDeletion) {
        val deleted = stringResource(R.string.statsDeletedTitle)
        val failed = stringResource(R.string.statsDeleteFailedTitle)
        val failedMessage = stringResource(R.string.statsDeleteFailedMessage)
        AlertDialog(
            onDismissRequest = { confirmingDeletion = false },
            containerColor = Theme.statsCard,
            title = { Text(stringResource(R.string.statsDeleteConfirmTitle), style = Theme.Typography.Heading.hero, color = Theme.textPrimary) },
            text = { Text(stringResource(R.string.statsDeleteConfirmMessage), style = Theme.Typography.Copy.body, color = Theme.mutedText) },
            confirmButton = {
                TextButton(onClick = {
                    confirmingDeletion = false
                    scope.launch {
                        result = if (actions.deleteStats()) deleted to null else failed to failedMessage
                    }
                }) { Text(stringResource(R.string.statsDeleteConfirmAction), style = Theme.Typography.Copy.link, color = Theme.liveRed) }
            },
            dismissButton = {
                TextButton(onClick = { confirmingDeletion = false }) {
                    Text(stringResource(R.string.statsDeleteCancel), style = Theme.Typography.Copy.link, color = Theme.textPrimary)
                }
            },
        )
    }
    result?.let { (title, message) ->
        AlertDialog(
            onDismissRequest = { result = null },
            containerColor = Theme.statsCard,
            title = { Text(title, style = Theme.Typography.Heading.hero, color = Theme.textPrimary) },
            text = message?.let { { Text(it, style = Theme.Typography.Copy.body, color = Theme.mutedText) } },
            confirmButton = { TextButton(onClick = { result = null }) { Text(stringResource(R.string.ok), color = Theme.liveRed) } },
        )
    }
}

/** Every show with a reminder switch (`ShowRemindersView.swift`). */
@Composable
fun ShowRemindersScreen(
    shows: List<Show>,
    followed: Set<String>,
    notificationsBlocked: Boolean,
    onToggle: (Show, Boolean) -> Unit,
    onUnfollowAll: () -> Unit,
    back: () -> Unit,
) {
    val context = LocalContext.current
    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp)
            .padding(top = 20.dp, bottom = Theme.Spacing.xl),
        verticalArrangement = Arrangement.spacedBy(Theme.Spacing.lg),
    ) {
        BackHeader(stringResource(R.string.showRemindersTitle), stringResource(R.string.close), back)
        Text(stringResource(R.string.showRemindersIntro), style = Theme.Typography.Copy.body, color = Theme.mutedText)
        if (notificationsBlocked) {
            Row(
                Modifier
                    .fillMaxWidth()
                    .background(Theme.statsCardRaised, RoundedCornerShape(12.dp))
                    .padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Icon(Icons.Rounded.NotificationsOff, null, tint = Theme.liveRed, modifier = Modifier.size(18.dp))
                Text(stringResource(R.string.notificationsBlockedToast), style = Theme.Typography.Copy.body, color = Theme.textPrimary, modifier = Modifier.weight(1f))
                Text(
                    stringResource(R.string.openSettingsAction), style = Theme.Typography.manrope(14f, FontWeight.ExtraBold), color = Theme.liveRed,
                    modifier = Modifier.clickable { openNotificationSettings(context) },
                )
            }
        }
        Column {
            for (show in shows) {
                ListDivider()
                ListRow(show.displayTitle, show.hostName) {
                    AppSwitch(show.id in followed) { onToggle(show, it) }
                }
            }
            ListDivider()
        }
        AnimatedVisibility(followed.isNotEmpty()) {
            SecondaryActionButton(stringResource(R.string.turnOffAllReminders), onClick = onUnfollowAll)
        }
    }
}
