package cz.slowdownradijo.app.message

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.Send
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.Info
import androidx.compose.material.icons.rounded.Mic
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import cz.slowdownradijo.app.R
import cz.slowdownradijo.app.home.tabular
import cz.slowdownradijo.app.ui.components.ListDivider
import cz.slowdownradijo.app.ui.components.PauseIcon
import cz.slowdownradijo.app.ui.components.PlayIcon
import cz.slowdownradijo.app.ui.components.PrimaryActionButton
import cz.slowdownradijo.app.ui.components.SecondaryActionButton
import cz.slowdownradijo.app.ui.theme.Theme

/** Everything the Vzkaz page shows. */
data class MessageUi(
    val state: VoiceMessageState,
    val elapsed: Double = 0.0,
    val levels: List<Float> = List(VoiceMessage.SEGMENTS) { 0f },
    val isPlaying: Boolean = false,
    val playbackProgress: Double = 0.0,
)

class MessageActions(
    val start: () -> Unit = {},
    val stop: () -> Unit = {},
    val cancel: () -> Unit = {},
    val togglePlayback: () -> Unit = {},
    val submit: () -> Unit = {},
    val retry: () -> Unit = {},
    val discard: () -> Unit = {},
    val recordAnother: () -> Unit = {},
    val backToRadio: () -> Unit = {},
)

private val successGreen = Color(0xFF28C840)

/** Vzkaz (`MessageView.swift`): record up to a minute, listen back, send it to the studio. */
@Composable
fun MessageContent(ui: MessageUi, actions: MessageActions) {
    Column(Modifier.padding(top = Theme.Spacing.sm), verticalArrangement = Arrangement.spacedBy(Theme.Spacing.lg)) {
        when (val state = ui.state) {
            VoiceMessageState.Ready -> {
                Header(stringResource(R.string.sendMessage), stringResource(R.string.sendMessageSubtitle))
                Row(
                    Modifier.fillMaxWidth().background(Theme.hairline(0.08f), RoundedCornerShape(10.dp)).padding(12.dp),
                    horizontalArrangement = Arrangement.spacedBy(Theme.Spacing.sm),
                ) {
                    Icon(Icons.Rounded.Info, null, tint = Theme.mutedText, modifier = Modifier.size(16.dp))
                    Text(stringResource(R.string.privacyNote), style = Theme.Typography.manrope(13f, FontWeight.Medium), color = Theme.mutedText)
                }
                ActionRow(stringResource(R.string.startRecording), stringResource(R.string.maxOneMinute), actions.start) {
                    Icon(Icons.Rounded.Mic, null, tint = Theme.textPrimary, modifier = Modifier.size(20.dp))
                }
            }
            VoiceMessageState.Recording -> {
                Header(stringResource(R.string.recordingInProgress), stringResource(R.string.tapToStop))
                ActionRow(formatted(ui.elapsed), stringResource(R.string.maxOneMinute), actions.stop) {
                    Box(Modifier.size(15.dp).background(Theme.textPrimary, RoundedCornerShape(4.dp)))
                }
                val active = minOf((minOf(ui.elapsed / VoiceMessage.MAX_SECONDS, 1.0) * VoiceMessage.SEGMENTS).toInt() + 1, VoiceMessage.SEGMENTS)
                Waveform(ui.levels, active)
                TextLink(stringResource(R.string.cancelRecording), Icons.Rounded.Close, actions.cancel)
            }
            is VoiceMessageState.Recorded, is VoiceMessageState.Sending -> {
                val seconds = (state as? VoiceMessageState.Recorded)?.seconds ?: (state as VoiceMessageState.Sending).seconds
                if (state is VoiceMessageState.Sending) {
                    Header(stringResource(R.string.sendingTitle), stringResource(R.string.sendingSubtitle))
                    ActionRow(stringResource(R.string.sendingButtonLabel), null, null) {
                        CircularProgressIndicator(Modifier.size(20.dp), color = Theme.textPrimary, strokeWidth = 2.dp)
                    }
                } else {
                    Recorded(ui, seconds, actions)
                }
            }
            VoiceMessageState.Sent -> {
                Box(Modifier.size(64.dp).background(successGreen.copy(alpha = 0.15f), CircleShape), contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.Check, null, tint = successGreen, modifier = Modifier.size(34.dp))
                }
                Column(verticalArrangement = Arrangement.spacedBy(Theme.Spacing.md)) {
                    StatusBadge(stringResource(R.string.sentBadge))
                    Header(stringResource(R.string.messageSent), stringResource(R.string.thankYouForMessage))
                }
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    PrimaryActionButton(stringResource(R.string.backToRadio), onClick = actions.backToRadio)
                    SecondaryActionButton(stringResource(R.string.recordAnotherMessage), onClick = actions.recordAnother)
                }
            }
        }
    }
}

@Composable
private fun Recorded(ui: MessageUi, seconds: Double, actions: MessageActions) {
    var confirmingDiscard by remember { mutableStateOf(false) }
    Column(verticalArrangement = Arrangement.spacedBy(Theme.Spacing.md)) {
        StatusBadge(stringResource(R.string.recorded))
        Header(stringResource(R.string.messageRecorded), stringResource(R.string.listenOrRerecord))
    }
    Column {
        ListDivider()
        Row(Modifier.padding(vertical = 20.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Theme.Spacing.md)) {
            AccentCircle(actions.togglePlayback, stringResource(if (ui.isPlaying) R.string.pauseRecording else R.string.playRecording)) {
                if (ui.isPlaying) PauseIcon(17.dp, Theme.textPrimary) else PlayIcon(17.dp, Theme.textPrimary, Modifier.padding(start = 2.dp))
            }
            Box(Modifier.weight(1f)) { Waveform(ui.levels, (ui.playbackProgress * VoiceMessage.SEGMENTS).toInt()) }
            Text(formatted(seconds), style = Theme.Typography.Copy.link.tabular(), color = Theme.mutedText)
        }
        ListDivider()
    }
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        PrimaryActionButton(stringResource(R.string.sendToRadio), icon = Icons.AutoMirrored.Rounded.Send, onClick = actions.submit)
        SecondaryActionButton(stringResource(R.string.recordAgain), onClick = actions.retry)
    }
    TextLink(stringResource(R.string.discardMessage), Icons.Rounded.Delete) { confirmingDiscard = true }
    if (confirmingDiscard) {
        AlertDialog(
            onDismissRequest = { confirmingDiscard = false },
            containerColor = Theme.statsCard,
            title = { Text(stringResource(R.string.discardMessageConfirm), style = Theme.Typography.Heading.hero, color = Theme.textPrimary) },
            confirmButton = {
                TextButton({ confirmingDiscard = false; actions.discard() }) {
                    Text(stringResource(R.string.discardMessage), style = Theme.Typography.Copy.link, color = Theme.liveRed)
                }
            },
            dismissButton = {
                TextButton({ confirmingDiscard = false }) { Text(stringResource(R.string.statsDeleteCancel), style = Theme.Typography.Copy.link, color = Theme.textPrimary) }
            },
        )
    }
}

@Composable
private fun Header(title: String, subtitle: String) {
    Column(verticalArrangement = Arrangement.spacedBy(Theme.Spacing.sm)) {
        Text(title, style = Theme.Typography.Heading.page, color = Theme.textPrimary)
        Text(subtitle, style = Theme.Typography.Copy.body, color = Theme.mutedText)
    }
}

@Composable
private fun AccentCircle(onClick: (() -> Unit)?, label: String? = null, content: @Composable () -> Unit) {
    Box(
        Modifier
            .shadow(6.dp, CircleShape)
            .size(46.dp)
            .clip(CircleShape)
            .background(Theme.liveRed)
            .then(if (onClick != null) Modifier.clickable(role = Role.Button, onClick = onClick) else Modifier)
            .then(if (label != null) Modifier.semantics { contentDescription = label } else Modifier),
        contentAlignment = Alignment.Center,
    ) { content() }
}

@Composable
private fun ActionRow(title: String, subtitle: String?, onClick: (() -> Unit)?, icon: @Composable () -> Unit) {
    Row(
        Modifier.fillMaxWidth().then(if (onClick != null) Modifier.clickable(role = Role.Button, onClick = onClick) else Modifier),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Theme.Spacing.md),
    ) {
        AccentCircle(null, content = icon)
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(title, style = Theme.Typography.Heading.item.tabular(), color = Theme.textPrimary)
            subtitle?.let { Text(it, style = Theme.Typography.Copy.body, color = Theme.mutedText) }
        }
    }
}

@Composable
private fun StatusBadge(label: String) {
    Row(
        Modifier.background(successGreen.copy(alpha = 0.15f), RoundedCornerShape(8.dp)).padding(horizontal = 12.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Box(Modifier.size(10.dp).background(successGreen, CircleShape))
        Text(label, style = Theme.Typography.manrope(14f, FontWeight.ExtraBold), color = successGreen)
    }
}

@Composable
private fun TextLink(title: String, icon: ImageVector, onClick: () -> Unit) {
    Row(Modifier.clickable(role = Role.Button, onClick = onClick), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Icon(icon, null, tint = Theme.textPrimary, modifier = Modifier.size(15.dp))
        Text(title, style = Theme.Typography.Copy.link, color = Theme.textPrimary)
    }
}

/** 18 capsules, red up to [activeCount], 3…40 high by level (`WaveformBarsView`). */
@Composable
private fun Waveform(levels: List<Float>, activeCount: Int) {
    Row(Modifier.fillMaxWidth().height(40.dp), horizontalArrangement = Arrangement.spacedBy(3.dp), verticalAlignment = Alignment.Bottom) {
        levels.forEachIndexed { index, level ->
            val active = index < activeCount
            val height by animateFloatAsState(if (active) maxOf(3f, level * 40f) else 3f, tween(150), label = "bar")
            Box(Modifier.weight(1f).height(height.dp).background(if (active) Theme.liveRed else Theme.waveformMuted, CircleShape))
        }
    }
}

/** "00:38" */
fun formatted(seconds: Double): String {
    val total = seconds.toInt()
    return "%02d:%02d".format(total / 60, total % 60)
}

/** The alerts for a refused microphone and a failed upload. */
@Composable
fun MessageAlert(title: String, message: String, onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = Theme.statsCard,
        title = { Text(title, style = Theme.Typography.Heading.hero, color = Theme.textPrimary) },
        text = { Text(message, style = Theme.Typography.Copy.body, color = Theme.mutedText) },
        confirmButton = { TextButton(onDismiss) { Text(stringResource(R.string.ok), color = Theme.liveRed) } },
    )
}
