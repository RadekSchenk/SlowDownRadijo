package cz.slowdownradijo.app.chat

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.offset
import androidx.compose.material.icons.automirrored.rounded.Reply
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.unit.IntOffset
import kotlinx.coroutines.launch
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

/** The curved line from a quote to the replier's name. */
val CHAT_SPINE = Color(0xFF5A507C)

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
 * Replies (1.4, Figma H1–H2) stay one line: "marty ↳ karolina.pivnivila  Taky sázíme…",
 * and "nela ↳ tobě" in white when it answers the listener.
 */
@Composable
fun ChatHomeSection(
    state: ChatService.State,
    onOpen: (withKeyboard: Boolean) -> Unit,
    onSeen: (Long) -> Unit,
    modifier: Modifier = Modifier,
    now: Instant = Instant.now(),
    /** The listener's user id: "↳ tobě" on replies to them. */
    viewerId: String? = null,
    /** A reply to the listener on screen when the section is tapped: the chat opens on it. */
    onFocus: (Long?) -> Unit = {},
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
            Modifier.fillMaxWidth().clickable {
                onFocus(current?.lastOrNull { it.message.replyTo?.isTo(viewerId) == true }?.message?.id)
                onOpen(false)
            },
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
                        val toYou = stringResource(R.string.chatHomeToYou)
                        Text(
                            buildAnnotatedString {
                                nameSpan(this, message.authorName ?: deletedName, message.role)
                                // " ↳ karolina.pivnivila", or " ↳ tobě" in white for a reply to the listener.
                                when (val quote = message.replyTo?.display(viewerId, state.hidden)) {
                                    is ChatQuote.Display.Message -> withStyle(SpanStyle(color = Theme.subtleText)) {
                                        append(" ↳ ${quote.name ?: deletedName}")
                                    }
                                    is ChatQuote.Display.Mine -> withStyle(SpanStyle(color = Theme.textPrimary, fontWeight = FontWeight.ExtraBold)) {
                                        append(" ↳ $toYou")
                                    }
                                    else -> Unit
                                }
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
fun ChatMessageRow(
    message: ChatMessage,
    onLongPress: () -> Unit = {},
    /** A reply's quote (Figma "Chat/Zpráva s odpovědí"), above the name. */
    quote: ChatQuote.Display? = null,
    onQuoteTap: (() -> Unit)? = null,
    /** Briefly tinted after jumping to it from a quote (R6). */
    highlighted: Boolean = false,
) {
    val tint by animateFloatAsState(if (highlighted) 0.07f else 0f, tween(if (highlighted) 200 else 450), label = "highlight")
    Column(
        Modifier
            .fillMaxWidth()
            .drawBehind {
                if (tint > 0f) {
                    val dx = 10.dp.toPx()
                    val dy = 6.dp.toPx()
                    drawRoundRect(
                        Color.White.copy(alpha = tint), topLeft = Offset(-dx, -dy),
                        size = Size(size.width + 2 * dx, size.height + 2 * dy), cornerRadius = CornerRadius(10.dp.toPx()),
                    )
                }
            }
            .combinedClickable(onClick = {}, onLongClick = onLongPress),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        if (quote != null) ChatQuoteLine(quote, onQuoteTap, Modifier.padding(bottom = 0.dp).offset(y = 2.dp))
        ChatAuthorLine(message.authorName ?: stringResource(R.string.deletedAccount), message.role)
        if (message.isDeleted) {
            Text(stringResource(R.string.chatDeletedByModerator), style = Theme.Typography.Copy.reading.copy(fontStyle = FontStyle.Italic), color = Theme.subtleText)
        } else {
            Text(message.body.orEmpty(), style = Theme.Typography.Copy.reading, color = Theme.textPrimary)
        }
    }
}

/**
 * The quote above a reply (Figma "Chat/Citace", variant A), as `ChatQuoteLine` in
 * ChatComponents.swift: one line, "karolina.pivnivila · Výsadba nové chmelnice…", and a
 * thin curved line from it down to the replier's name. Tapping it jumps to the original.
 */
@Composable
fun ChatQuoteLine(display: ChatQuote.Display, onClick: (() -> Unit)? = null, modifier: Modifier = Modifier) {
    val deleted = stringResource(R.string.deletedAccount)
    val you = stringResource(R.string.chatQuoteYou)
    val unavailable = stringResource(R.string.chatQuoteUnavailable)
    val subtle = SpanStyle(color = Theme.subtleText)
    val text = buildAnnotatedString {
        when (display) {
            is ChatQuote.Display.Message -> {
                nameSpan(this, display.name ?: deleted, display.role)
                withStyle(subtle) { append(" · ${display.body}") }
            }
            is ChatQuote.Display.Mine -> {
                withStyle(SpanStyle(color = Theme.textPrimary, fontWeight = FontWeight.ExtraBold)) { append(you) }
                withStyle(subtle) { append(" · ${display.body}") }
            }
            ChatQuote.Display.Unavailable -> withStyle(subtle) { append(unavailable) }
        }
    }
    val label = when (display) {
        is ChatQuote.Display.Message -> stringResource(R.string.chatReplyTo, display.name ?: deleted) + ": " + display.body
        is ChatQuote.Display.Mine -> stringResource(R.string.chatReplyToYou) + ": " + display.body
        ChatQuote.Display.Unavailable -> unavailable
    }
    val tappable = onClick != null && display != ChatQuote.Display.Unavailable
    Row(
        modifier
            .fillMaxWidth()
            .then(if (tappable) Modifier.clickable(onClick = onClick!!) else Modifier)
            .semantics(mergeDescendants = true) { contentDescription = label },
        verticalAlignment = Alignment.Bottom,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        ChatSpine(Modifier.size(width = 26.dp, height = 14.dp))
        Text(text, style = Theme.Typography.Copy.label, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.offset(y = 3.dp))
    }
}

/** ╭── from the quote, bending down towards the name below. */
@Composable
fun ChatSpine(modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val sx = size.width / 26f
        val sy = size.height / 14f
        val path = Path().apply {
            moveTo(5 * sx, 14 * sy)
            lineTo(5 * sx, 9.5f * sy)
            cubicTo(5 * sx, 6.5f * sy, 7 * sx, 5 * sy, 10 * sx, 5 * sy)
            lineTo(24 * sx, 5 * sy)
        }
        drawPath(path, CHAT_SPINE, style = Stroke(width = 2.dp.toPx(), cap = StrokeCap.Round))
    }
}

/**
 * Swipe a message to the right to answer it (Figma R1), as `swipeToReply` in
 * ChatSheetView.swift: it follows the finger up to 56 dp (a tick of haptics), then
 * slower; letting go past that starts the reply. A reply arrow shows up behind it.
 */
@Composable
fun SwipeToReply(enabled: Boolean, onReply: () -> Unit, content: @Composable () -> Unit) {
    if (!enabled) {
        content()
        return
    }
    val haptics = LocalHapticFeedback.current
    val threshold = with(LocalDensity.current) { 56.dp.toPx() }
    val offset = remember { Animatable(0f) }
    val scope = rememberCoroutineScope()
    val reply by rememberUpdatedState(onReply)
    var armed by remember { mutableStateOf(false) }
    Box {
        val progress = (offset.value / threshold).coerceIn(0f, 1f)
        Box(
            Modifier
                .align(Alignment.CenterStart)
                .size(32.dp)
                .alpha(progress)
                .scale(if (armed) 1f else 0.8f)
                .background(Theme.statsCardRaised, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.AutoMirrored.Rounded.Reply, contentDescription = null, tint = Theme.textPrimary, modifier = Modifier.size(18.dp))
        }
        Box(
            Modifier
                .offset { IntOffset(offset.value.toInt(), 0) }
                .pointerInput(Unit) {
                    var total = 0f
                    detectHorizontalDragGestures(
                        onDragStart = { total = 0f },
                        onDragEnd = {
                            if (armed) reply()
                            armed = false
                            scope.launch { offset.animateTo(0f, tween(250)) }
                        },
                        onDragCancel = {
                            armed = false
                            scope.launch { offset.animateTo(0f, tween(250)) }
                        },
                    ) { change, dx ->
                        total = (total + dx).coerceAtLeast(0f)
                        if (total > 0f) change.consume()
                        val value = if (total <= threshold) total else threshold + (total - threshold) * 0.25f
                        scope.launch { offset.snapTo(value) }
                        val nowArmed = value >= threshold
                        if (nowArmed != armed) {
                            armed = nowArmed
                            if (nowArmed) haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                        }
                    }
                },
        ) { content() }
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
fun ChatOutgoingRow(message: OutgoingChatMessage, name: String, role: String, quote: ChatQuote.Display? = null, onRetry: () -> Unit) {
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        if (quote != null) ChatQuoteLine(quote, modifier = Modifier.offset(y = 2.dp))
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
fun ChatPinnedBar(message: ChatMessage, onLongPress: () -> Unit = {}) {
    Row(
        Modifier.fillMaxWidth().background(Theme.statsCard)
            .combinedClickable(onClick = {}, onLongClick = onLongPress)
            .padding(horizontal = 20.dp, vertical = 10.dp),
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
