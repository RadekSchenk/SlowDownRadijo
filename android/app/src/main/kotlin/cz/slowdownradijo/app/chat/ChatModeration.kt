package cz.slowdownradijo.app.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.VolumeOff
import androidx.compose.material.icons.automirrored.rounded.VolumeUp
import androidx.compose.material.icons.outlined.Flag
import androidx.compose.material.icons.outlined.PushPin
import androidx.compose.material.icons.outlined.VisibilityOff
import androidx.compose.material.icons.rounded.Block
import androidx.compose.material.icons.rounded.ContentCopy
import androidx.compose.material.icons.rounded.DeleteOutline
import androidx.compose.material.icons.rounded.PushPin
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import cz.slowdownradijo.app.R
import cz.slowdownradijo.app.data.ScheduleStore.Companion.STATION_ZONE
import cz.slowdownradijo.app.profile.ProfileActions
import cz.slowdownradijo.app.profile.ProfileHeading
import cz.slowdownradijo.app.profile.SignInButtons
import cz.slowdownradijo.app.profile.dayAndTime
import cz.slowdownradijo.app.ui.components.PrimaryActionButton
import cz.slowdownradijo.app.ui.components.SecondaryActionButton
import cz.slowdownradijo.app.ui.theme.Theme
import java.time.Instant
import java.time.format.DateTimeFormatter

/** What pressing and holding a message offers (Figma L1, L2/Z1, Z4). */
enum class ChatMenuAction { PIN, UNPIN, COPY, DELETE, MUTE, UNMUTE, BLOCK, REPORT, HIDE }

/**
 * The actions for a message by who is looking, as `ChatMenu` in ChatModerationViews.swift:
 * a listener copies, reports and hides others; a DJ or admin also pins, deletes, mutes
 * and blocks, but never another moderator nor themselves.
 */
object ChatMenu {
    fun actions(message: ChatMessage, viewer: String?, isModerator: Boolean, isPinned: Boolean, status: ChatService.UserStatus?): List<ChatMenuAction> {
        if (message.isDeleted) return emptyList()
        val author = message.userId
        val own = author != null && author == viewer
        val out = mutableListOf<ChatMenuAction>()
        if (isModerator) out += if (isPinned) ChatMenuAction.UNPIN else ChatMenuAction.PIN
        out += ChatMenuAction.COPY
        if (isModerator) {
            out += ChatMenuAction.DELETE
            val authorIsModerator = message.role == "dj" || message.role == "admin"
            if (author != null && !own && !authorIsModerator && status?.blocked != true) {
                out += if (status?.isMuted == true) ChatMenuAction.UNMUTE else ChatMenuAction.MUTE
                out += ChatMenuAction.BLOCK
            }
        } else if (!own) {
            out += ChatMenuAction.REPORT
            if (viewer != null && author != null) out += ChatMenuAction.HIDE
        }
        return out
    }

    fun isDestructive(action: ChatMenuAction) = action in setOf(ChatMenuAction.DELETE, ChatMenuAction.MUTE, ChatMenuAction.BLOCK)

    fun icon(action: ChatMenuAction): ImageVector = when (action) {
        ChatMenuAction.PIN -> Icons.Outlined.PushPin
        ChatMenuAction.UNPIN -> Icons.Rounded.PushPin
        ChatMenuAction.COPY -> Icons.Rounded.ContentCopy
        ChatMenuAction.DELETE -> Icons.Rounded.DeleteOutline
        ChatMenuAction.MUTE -> Icons.AutoMirrored.Rounded.VolumeOff
        ChatMenuAction.UNMUTE -> Icons.AutoMirrored.Rounded.VolumeUp
        ChatMenuAction.BLOCK -> Icons.Rounded.Block
        ChatMenuAction.REPORT -> Icons.Outlined.Flag
        ChatMenuAction.HIDE -> Icons.Outlined.VisibilityOff
    }
}

/** The message menu: the message, when and in which show, then the actions. */
@Composable
fun ChatMessageMenu(
    message: ChatMessage,
    actions: List<ChatMenuAction>,
    status: ChatService.UserStatus?,
    now: Instant,
    onAction: (ChatMenuAction) -> Unit,
) {
    val words = chatWords()
    val name = message.authorName ?: stringResource(R.string.deletedAccount)
    Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp).padding(top = 8.dp, bottom = 12.dp).navigationBarsPadding()) {
        Column(Modifier.padding(bottom = 14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            ChatAuthorLine(name, message.role)
            if (!message.isDeleted) Text(message.body.orEmpty(), style = Theme.Typography.Copy.reading, color = Theme.textPrimary, maxLines = 3)
            Text(ChatTimeline.timeLine(message, now, STATION_ZONE, words), style = Theme.Typography.Copy.label, color = Theme.subtleText)
            statusLine(status, now)?.let { line ->
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Icon(Icons.AutoMirrored.Rounded.VolumeOff, contentDescription = null, tint = Theme.mutedText, modifier = Modifier.size(14.dp))
                    Text(line, style = Theme.Typography.Copy.label, color = Theme.mutedText)
                }
            }
        }
        if (actions.isNotEmpty()) HorizontalDivider(color = Theme.statsCardRaised)
        Column(Modifier.padding(top = 6.dp)) {
            actions.forEach { action ->
                val color = if (ChatMenu.isDestructive(action)) Theme.liveRed else Theme.textPrimary
                Row(
                    Modifier.fillMaxWidth().height(52.dp).clickable { onAction(action) },
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    Icon(ChatMenu.icon(action), contentDescription = null, tint = color, modifier = Modifier.size(22.dp))
                    Text(title(action, name), style = Theme.Typography.manrope(16f, FontWeight.SemiBold), color = color, modifier = Modifier.weight(1f))
                    if (action == ChatMenuAction.UNMUTE) remaining(status, now)?.let {
                        Text(it, style = Theme.Typography.Copy.label, color = Theme.subtleText)
                    }
                }
            }
        }
    }
}

@Composable
private fun title(action: ChatMenuAction, name: String): String = when (action) {
    ChatMenuAction.PIN -> stringResource(R.string.chatMenuPin)
    ChatMenuAction.UNPIN -> stringResource(R.string.chatMenuUnpin)
    ChatMenuAction.COPY -> stringResource(R.string.chatMenuCopy)
    ChatMenuAction.DELETE -> stringResource(R.string.chatMenuDelete)
    ChatMenuAction.MUTE -> stringResource(R.string.chatMenuMute)
    ChatMenuAction.UNMUTE -> stringResource(R.string.chatMenuUnmute)
    ChatMenuAction.BLOCK -> stringResource(R.string.chatMenuBlock)
    ChatMenuAction.REPORT -> stringResource(R.string.chatMenuReport)
    ChatMenuAction.HIDE -> stringResource(R.string.chatMenuHide, name)
}

@Composable
private fun statusLine(status: ChatService.UserStatus?, now: Instant): String? {
    status ?: return null
    val by = status.mutedBy ?: "—"
    if (status.blocked) return stringResource(R.string.chatBlockedStatus, by)
    val until = status.mutedUntil?.takeIf { it > now } ?: return null
    val (day, time) = dayAndTime(until, now)
    return stringResource(R.string.chatMutedStatus, day, time, by)
}

@Composable
private fun remaining(status: ChatService.UserStatus?, now: Instant): String? {
    val until = status?.mutedUntil ?: return null
    val minutes = ((until.epochSecond - now.epochSecond) / 60).toInt()
    if (minutes <= 0) return null
    return if (minutes >= 60) stringResource(R.string.chatRemainingHours, minutes / 60) else stringResource(R.string.chatRemainingMinutes, minutes)
}

/** "Ztlumit brancikovac": 1 h / 24 h / 7 dní, 24 h preselected (Figma Z2). */
@Composable
fun ChatMuteContent(name: String, onMute: (Int) -> Unit, onCancel: () -> Unit, initialMinutes: Int = 1440) {
    var minutes by remember { mutableIntStateOf(initialMinutes) }
    val options = listOf(60 to R.string.chatMuteHour, 1440 to R.string.chatMuteDay, 10080 to R.string.chatMuteWeek)
    Column(
        Modifier.fillMaxWidth().padding(horizontal = 20.dp).padding(top = 8.dp, bottom = 12.dp).navigationBarsPadding(),
        verticalArrangement = Arrangement.spacedBy(Theme.Spacing.md),
    ) {
        ProfileHeading(stringResource(R.string.chatMuteTitle, name), stringResource(R.string.chatMuteBody), hero = true)
        Column {
            options.forEachIndexed { index, (value, label) ->
                Row(
                    Modifier.fillMaxWidth().height(52.dp).selectable(selected = minutes == value, role = Role.RadioButton) { minutes = value },
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(stringResource(label), style = Theme.Typography.manrope(16f, FontWeight.SemiBold), color = Theme.textPrimary, modifier = Modifier.weight(1f))
                    RadioButton(
                        selected = minutes == value, onClick = null,
                        colors = RadioButtonDefaults.colors(selectedColor = Theme.liveRed, unselectedColor = Theme.mutedText),
                    )
                }
                if (index < options.lastIndex) HorizontalDivider(color = Theme.statsCardRaised)
            }
        }
        val action = when (minutes) {
            60 -> R.string.chatMuteActionHour
            10080 -> R.string.chatMuteActionWeek
            else -> R.string.chatMuteActionDay
        }
        PrimaryActionButton(stringResource(action)) { onMute(minutes) }
        SecondaryActionButton(stringResource(R.string.cancel), onClick = onCancel)
    }
}

/** "Zablokovat brancikovac?" (Figma Z5). */
@Composable
fun ChatBlockContent(name: String, onBlock: () -> Unit, onCancel: () -> Unit) {
    Column(
        Modifier.fillMaxWidth().padding(horizontal = 20.dp).padding(top = 8.dp, bottom = 12.dp).navigationBarsPadding(),
        verticalArrangement = Arrangement.spacedBy(Theme.Spacing.md),
    ) {
        ProfileHeading(stringResource(R.string.chatBlockTitle, name), stringResource(R.string.chatBlockBody), hero = true)
        PrimaryActionButton(stringResource(R.string.chatBlockAction), onClick = onBlock)
        SecondaryActionButton(stringResource(R.string.cancel), onClick = onCancel)
    }
}

/** The DJ invite's states (Figma P1–P3). */
sealed interface InvitePhase {
    data object Loading : InvitePhase
    data class Ready(val info: ChatService.InviteInfo?, val linking: Boolean) : InvitePhase
    data class Done(val hostName: String) : InvitePhase
    data class Invalid(val otherHost: Boolean) : InvitePhase
}

@Composable
fun HostInviteContent(
    phase: InvitePhase,
    busy: Boolean,
    actions: ProfileActions,
    onOpenChat: () -> Unit,
    onClose: () -> Unit,
) {
    Column(
        Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(top = 8.dp, bottom = 24.dp).navigationBarsPadding(),
        verticalArrangement = Arrangement.spacedBy(Theme.Spacing.lg),
    ) {
        when (phase) {
            InvitePhase.Loading -> Box(Modifier.fillMaxWidth().padding(32.dp), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = Theme.textPrimary, strokeWidth = 2.dp, modifier = Modifier.size(28.dp))
            }
            is InvitePhase.Invalid -> {
                ProfileHeading(
                    stringResource(R.string.inviteInvalidTitle),
                    if (phase.otherHost) stringResource(R.string.errorInviteOtherHost) else stringResource(R.string.inviteInvalidBody),
                    hero = true,
                )
                SecondaryActionButton(stringResource(R.string.inviteClose), onClick = onClose)
            }
            is InvitePhase.Ready -> {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(stringResource(R.string.inviteKicker).uppercase(), style = Theme.Typography.manrope(13f, FontWeight.ExtraBold), color = Theme.liveRed)
                    ProfileHeading(
                        phase.info?.let { stringResource(R.string.inviteTitle, it.hostName) } ?: stringResource(R.string.inviteTitleGeneric),
                        stringResource(R.string.inviteBody), hero = true,
                    )
                }
                InviteSample(phase.info?.hostName ?: "DJ")
                if (phase.linking) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        CircularProgressIndicator(color = Theme.textPrimary, strokeWidth = 2.dp, modifier = Modifier.size(20.dp))
                        Text(stringResource(R.string.inviteLinking), style = Theme.Typography.Copy.body, color = Theme.mutedText)
                    }
                } else {
                    SignInButtons(busy, actions.onApple, actions.onGoogle, actions.onEmail)
                }
                val expires = phase.info?.expiresAt
                Text(
                    if (expires != null) stringResource(R.string.inviteValidUntil, DateTimeFormatter.ofPattern("d. M.").format(expires.atZone(STATION_ZONE)))
                    else stringResource(R.string.inviteOneUse),
                    style = Theme.Typography.Copy.label, color = Theme.subtleText, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth(),
                )
            }
            is InvitePhase.Done -> {
                ProfileHeading(stringResource(R.string.inviteDoneTitle, phase.hostName), stringResource(R.string.inviteDoneBody), hero = true)
                InviteSample(phase.hostName)
                Text(stringResource(R.string.inviteDoneHint), style = Theme.Typography.Copy.body, color = Theme.mutedText)
                PrimaryActionButton(stringResource(R.string.inviteOpenChat), onClick = onOpenChat)
            }
        }
    }
}

@Composable
private fun InviteSample(name: String) {
    Column(
        Modifier.fillMaxWidth().background(Theme.statsCardRaised, RoundedCornerShape(14.dp)).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        ChatAuthorLine(name, "dj")
        Text(stringResource(R.string.inviteSample), style = Theme.Typography.Copy.reading, color = Theme.textPrimary)
    }
}
