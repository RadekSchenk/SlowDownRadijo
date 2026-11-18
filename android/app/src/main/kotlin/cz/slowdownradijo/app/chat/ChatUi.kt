package cz.slowdownradijo.app.chat

import androidx.compose.animation.core.tween
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.rounded.Send
import androidx.compose.material.icons.rounded.PushPin
import androidx.compose.material.icons.rounded.SentimentSatisfied
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import cz.slowdownradijo.app.R
import cz.slowdownradijo.app.l10n.LocalAppLanguage
import cz.slowdownradijo.app.ui.components.LocalAnimationsEnabled
import cz.slowdownradijo.app.ui.components.LocalReduceMotion
import cz.slowdownradijo.app.ui.theme.Theme
import kotlinx.coroutines.delay
import java.time.Duration
import java.time.Instant

// Roles: only the name's colour changes (Figma "Chat/Zpráva").

fun chatNameColor(role: String): Color = when (role) {
    "supporter" -> Theme.gold
    "dj", "admin" -> Theme.liveRed
    else -> Theme.mutedText
}

val CHAT_QUICK_EMOJI = listOf("🔥", "❤️", "😂", "🎵", "👏", "💜", "🎧")

val CHAT_PICKER_EMOJI = listOf(
    "😀", "😂", "🥲", "😍", "😎", "🤩", "🥳", "😴",
    "🤔", "😮", "😢", "😡", "🙏", "👏", "🙌", "👋",
    "👍", "👎", "💪", "🤘", "✌️", "🫶", "❤️", "💜",
    "🔥", "✨", "🎵", "🎶", "🎧", "🎙️", "📻", "💿",
    "☕️", "🍺", "🍷", "🌙", "☀️", "🌧️", "🌊", "🌿",
)

@Composable
fun chatWords(): ChatTimeline.Words = ChatTimeline.Words(
    today = stringResource(R.string.chatToday),
    yesterday = stringResource(R.string.chatYesterday),
    noShow = stringResource(R.string.chatNoShow),
    deletedAccount = stringResource(R.string.deletedAccount),
    english = LocalAppLanguage.current.isEnglish,
)

/** "nela, marty a 2 další" */
@Composable
fun chatNames(names: List<String>): String {
    val english = LocalAppLanguage.current.isEnglish
    return if (names.size <= 2) names.joinToString(if (english) " and " else " a ")
    else stringResource(R.string.chatNamesAndMore, names.take(2).joinToString(", "), names.size - 2)
}

private fun nameSpan(builder: AnnotatedString.Builder, name: String, role: String) {
    builder.withStyle(SpanStyle(color = chatNameColor(role), fontWeight = FontWeight.ExtraBold, fontSize = 13.sp)) {
        append(name)
        if (role == "supporter") append(" ★")
    }
}

// Home page (Figma "A1 · Homepage — chat", "A2 · Homepage — ticho")

private const val TICKER_LINES = 4
private val tickerOpacity = listOf(1f, 0.8f, 0.6f, 0.4f)

/**
 * The chat on the home page, as `ChatHomeSection.swift`: the "Chat" heading with a
 * chevron, the last four messages one line each (the newest at the bottom in white,
 * older ones fading out) and a "Napiš zprávu…" field that opens the chat with the
 * keyboard. New messages arrive by movement: 600 ms after opening the app the ones
 * the listener hasn't seen play in one by one, 1.2 s apart (more than four: one change).
 */
@Composable
fun ChatHomeSection(
    state: ChatService.State,
    onOpen: (withKeyboard: Boolean) -> Unit,
    onSeen: (Long) -> Unit,
    modifier: Modifier = Modifier,
    now: Instant = Instant.now(),
) {
    val candidates = ChatTimeline.homeLines(state.visibleMessages.filterNot { it.isDeleted })
    var shown by remember { mutableStateOf<List<ChatTimeline.HomeLine>?>(null) }
    val animate = LocalAnimationsEnabled.current && !LocalReduceMotion.current
    val latest by rememberUpdatedState(candidates)
    val seen by rememberUpdatedState(onSeen)
    val lastSeen by rememberUpdatedState(state.lastSeenId)

    if (shown == null && state.loaded) {
        shown = if (animate) candidates.filter { it.id <= state.lastSeenId }.takeLast(TICKER_LINES)
        else candidates.takeLast(TICKER_LINES)
    }
    // Renamed, deleted or hidden since: keep what's on screen up to date.
    val current = shown?.mapNotNull { old -> candidates.firstOrNull { it.id == old.id } }

    LaunchedEffect(state.loaded, candidates.lastOrNull()?.id, candidates.lastOrNull()?.count, state.lastSeenId) {
        if (!state.loaded) return@LaunchedEffect
        var first = true
        while (true) {
            val all = latest
            var onScreen = shown.orEmpty().mapNotNull { old -> all.firstOrNull { it.id == old.id } }
            // Read in the open chat meanwhile (the listener's own messages too):
            // shown as they are, the ticker only plays what nobody has seen.
            val seenLines = all.filter { it.id <= lastSeen }
            if (seenLines.isNotEmpty() && seenLines.last().id > (onScreen.lastOrNull()?.id ?: 0L)) {
                onScreen = seenLines.takeLast(TICKER_LINES)
                shown = onScreen
            }
            val after = onScreen.lastOrNull()?.id ?: lastSeen
            val pending = all.filter { it.id > after }
            if (pending.isEmpty()) {
                shown = onScreen
                break
            }
            if (animate) delay(if (first) 600 else 1200)
            first = false
            shown = if (pending.size > TICKER_LINES || !animate) all.takeLast(TICKER_LINES)
            else (onScreen + pending.first()).takeLast(TICKER_LINES)
            shown?.lastOrNull()?.let { seen(it.id) }
        }
    }

    val quiet = state.loaded && (candidates.lastOrNull()?.message?.createdAt?.let { it < now.minus(Duration.ofHours(24)) } ?: true)

    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(Theme.Spacing.md)) {
        Column(
            Modifier.fillMaxWidth().clickable { onOpen(false) },
            verticalArrangement = Arrangement.spacedBy(Theme.Spacing.md),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    stringResource(R.string.chatTitle),
                    style = Theme.Typography.Heading.section.copy(lineHeight = 26.sp), color = Theme.textPrimary,
                    modifier = Modifier.weight(1f).semantics { heading() },
                )
                Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, contentDescription = stringResource(R.string.chatOpen), tint = Theme.mutedText)
            }
            if (quiet) {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    state.pinned?.body?.let { body ->
                        Text(
                            buildAnnotatedString {
                                withStyle(SpanStyle(color = Theme.liveRed)) { append("📌 ") }
                                nameSpan(this, state.pinned.authorName ?: stringResource(R.string.deletedAccount), state.pinned.role)
                                withStyle(SpanStyle(color = Theme.textPrimary)) { append("  $body") }
                            },
                            style = Theme.Typography.Copy.body, maxLines = 1, overflow = TextOverflow.Ellipsis,
                        )
                    }
                    Text(stringResource(R.string.chatHomeQuiet), style = Theme.Typography.Copy.body, color = Theme.mutedText, maxLines = 2)
                }
            } else {
                val lines = current.orEmpty()
                val count = lines.size.coerceIn(1, TICKER_LINES)
                LazyColumn(
                    Modifier.fillMaxWidth().height((count * 20 + (count - 1) * 6).dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp, Alignment.Bottom),
                    userScrollEnabled = false,
                ) {
                    items(lines, key = { it.id }) { line ->
                        val message = line.message
                        val fromBottom = lines.size - 1 - lines.indexOf(line)
                        val deletedName = stringResource(R.string.deletedAccount)
                        Text(
                            buildAnnotatedString {
                                nameSpan(this, message.authorName ?: deletedName, message.role)
                                withStyle(SpanStyle(color = if (fromBottom == 0) Theme.textPrimary else Theme.mutedText)) {
                                    append("  ${message.body.orEmpty()}")
                                    if (line.count > 1) append(" ×${line.count}")
                                }
                            },
                            style = Theme.Typography.Copy.body, maxLines = 1, overflow = TextOverflow.Ellipsis,
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(20.dp)
                                // Older lines fade out: 100 / 80 / 60 / 40 %.
                                .alpha(tickerOpacity[minOf(fromBottom, tickerOpacity.size - 1)])
                                .then(
                                    if (animate) Modifier.animateItem(
                                        fadeInSpec = tween(350), placementSpec = tween(350), fadeOutSpec = tween(200),
                                    ) else Modifier
                                ),
                        )
                    }
                }
            }
        }
        Row(
            Modifier
                .fillMaxWidth()
                .height(44.dp)
                .background(Theme.statsCardRaised, RoundedCornerShape(22.dp))
                .clickable { onOpen(true) }
                .padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(stringResource(R.string.chatPlaceholder), style = Theme.Typography.Copy.reading, color = Theme.subtleText, modifier = Modifier.weight(1f))
            Icon(Icons.Rounded.SentimentSatisfied, contentDescription = null, tint = Theme.mutedText, modifier = Modifier.size(20.dp))
        }
    }
}

// Chat sheet rows

@Composable
fun ChatAuthorLine(name: String, role: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(name, style = Theme.Typography.manrope(13f, FontWeight.ExtraBold), color = chatNameColor(role), maxLines = 1)
        if (role == "supporter") Text("★", style = Theme.Typography.manrope(13f, FontWeight.ExtraBold), color = Theme.gold)
        if (role == "dj") cz.slowdownradijo.app.profile.DjTag()
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun ChatMessageRow(message: ChatMessage, onLongPress: () -> Unit = {}) {
    Column(
        Modifier.fillMaxWidth().combinedClickable(onClick = {}, onLongClick = onLongPress),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        ChatAuthorLine(message.authorName ?: stringResource(R.string.deletedAccount), message.role)
        if (message.isDeleted) {
            Text(stringResource(R.string.chatDeletedByModerator), style = Theme.Typography.Copy.reading.copy(fontStyle = FontStyle.Italic), color = Theme.subtleText)
        } else {
            Text(message.body.orEmpty(), style = Theme.Typography.Copy.reading, color = Theme.textPrimary)
        }
    }
}

@Composable
fun ChatEmojiRow(emoji: String, count: Int, names: List<String>) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(emoji, fontSize = 20.sp)
        Text("×$count", style = Theme.Typography.manrope(13f, FontWeight.ExtraBold), color = Theme.textPrimary)
        Text(chatNames(names), style = Theme.Typography.Copy.label, color = Theme.mutedText, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
fun ChatDividerRow(text: String) {
    Row(Modifier.fillMaxWidth().semantics { heading() }, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Box(Modifier.weight(1f).height(1.dp).background(Theme.subtleText.copy(alpha = 0.3f)))
        Text(text, style = Theme.Typography.Copy.label, color = Theme.subtleText, maxLines = 1, overflow = TextOverflow.Ellipsis)
        Box(Modifier.weight(1f).height(1.dp).background(Theme.subtleText.copy(alpha = 0.3f)))
    }
}

@Composable
fun ChatOutgoingRow(message: OutgoingChatMessage, name: String, role: String, onRetry: () -> Unit) {
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        ChatAuthorLine(name, role)
        Text(message.body, style = Theme.Typography.Copy.reading, color = if (message.failed) Theme.textPrimary else Theme.textPrimary.copy(alpha = 0.6f))
        if (message.failed) {
            Text(
                "${stringResource(R.string.chatNotSent)} · ${stringResource(R.string.chatRetry)}",
                style = Theme.Typography.manrope(13f, FontWeight.Bold), color = Theme.liveRed,
                modifier = Modifier.clickable(onClick = onRetry),
            )
        } else {
            Text(stringResource(R.string.chatSending), style = Theme.Typography.Copy.label, color = Theme.subtleText)
        }
    }
}

@Composable
fun ChatPinnedBar(message: ChatMessage) {
    Row(
        Modifier.fillMaxWidth().background(Theme.statsCard).padding(horizontal = 20.dp, vertical = 10.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(Icons.Rounded.PushPin, contentDescription = null, tint = Theme.liveRed, modifier = Modifier.padding(top = 2.dp).size(16.dp))
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                "${stringResource(R.string.chatPinned)} · ${message.authorName ?: stringResource(R.string.deletedAccount)}",
                style = Theme.Typography.manrope(13f, FontWeight.ExtraBold), color = Theme.liveRed,
            )
            Text(message.body.orEmpty(), style = Theme.Typography.manrope(15f, FontWeight.SemiBold), color = Theme.textPrimary, maxLines = 2, overflow = TextOverflow.Ellipsis)
        }
    }
}

@Composable
fun ChatSendButton(enabled: Boolean, onClick: () -> Unit) {
    Box(
        Modifier
            .size(44.dp)
            .background(if (enabled) Theme.liveRed else Theme.statsCardRaised, CircleShape)
            .clickable(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            Icons.AutoMirrored.Rounded.Send, contentDescription = stringResource(R.string.chatSend),
            tint = if (enabled) Theme.textPrimary else Theme.mutedText, modifier = Modifier.size(20.dp),
        )
    }
}
