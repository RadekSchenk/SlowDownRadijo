package cz.slowdownradijo.app.chat

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.automirrored.rounded.VolumeOff
import androidx.compose.material.icons.automirrored.rounded.VolumeUp
import androidx.compose.material.icons.outlined.Flag
import androidx.compose.material.icons.outlined.VisibilityOff
import androidx.compose.material.icons.rounded.Block
import androidx.compose.material.icons.rounded.DeleteOutline
import androidx.compose.material.icons.rounded.PushPin
import androidx.compose.material.icons.rounded.ErrorOutline
import androidx.compose.material.icons.rounded.CheckCircleOutline
import androidx.compose.material.icons.rounded.Keyboard
import androidx.compose.material.icons.rounded.SentimentSatisfied
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import cz.slowdownradijo.app.R
import cz.slowdownradijo.app.account.AccountError
import cz.slowdownradijo.app.account.AccountService
import cz.slowdownradijo.app.app
import cz.slowdownradijo.app.data.ScheduleStore
import cz.slowdownradijo.app.data.ScheduleStore.Companion.STATION_ZONE
import cz.slowdownradijo.app.data.Show
import cz.slowdownradijo.app.l10n.L10nLogic
import cz.slowdownradijo.app.l10n.LocalAppLanguage
import cz.slowdownradijo.app.profile.ChatRulesScreen
import cz.slowdownradijo.app.profile.EmailSignInScreen
import cz.slowdownradijo.app.profile.MutedBanner
import cz.slowdownradijo.app.profile.NicknameSetup
import cz.slowdownradijo.app.profile.ProfileActions
import cz.slowdownradijo.app.profile.ProfileHeading
import cz.slowdownradijo.app.profile.SignInButtons
import cz.slowdownradijo.app.profile.signInActions
import cz.slowdownradijo.app.ui.components.ToastCenter
import cz.slowdownradijo.app.ui.theme.Theme
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.launch
import java.time.Instant

/** What the composer may do (Figma B, G, L3). */
data class ChatWriter(
    val signedIn: Boolean,
    val name: String?,
    val role: String,
    val mutedUntil: Instant?,
    val blocked: Boolean,
) {
    val canWrite: Boolean get() = !blocked && mutedUntil == null
    val hasName: Boolean get() = signedIn && name != null

    companion object {
        fun of(state: AccountService.State, now: Instant): ChatWriter {
            val me = (state as? AccountService.State.SignedIn)?.me
            return ChatWriter(
                signedIn = state is AccountService.State.SignedIn,
                name = me?.chatName,
                role = me?.role ?: "listener",
                mutedUntil = me?.mutedUntil?.takeIf { it > now },
                blocked = me?.blocked == true,
            )
        }
    }
}

/**
 * The chat sheet's content (Figma "Chat sheet", B–G, K, L3), as `ChatSheetView.swift`:
 * header with the show on air, the pinned message, the stream with its dividers, and
 * the composer (quick emoji, the field, send), or the muted banner.
 */
@Composable
fun ChatContent(
    state: ChatService.State,
    show: Show?,
    writer: ChatWriter,
    draft: String,
    onDraft: (String) -> Unit,
    onSend: (text: String, clearsDraft: Boolean) -> Unit,
    onRetry: (String) -> Unit,
    onClose: () -> Unit,
    onRules: () -> Unit,
    onSeen: () -> Unit,
    showLabel: (showId: String?, title: String?, at: Instant) -> ChatTimeline.ShowLabel?,
    modifier: Modifier = Modifier,
    now: Instant = Instant.now(),
    focusRequester: FocusRequester = remember { FocusRequester() },
    initialEmojiOpen: Boolean = false,
    onLongPress: (ChatMessage) -> Unit = {},
) {
    val words = chatWords()
    val rows = ChatTimeline.rows(state.messages, words, state.outgoing, state.outgoingShow, state.hidden, now, STATION_ZONE, showLabel)
    var emojiOpen by remember { mutableStateOf(initialEmojiOpen) }
    val focusManager = LocalFocusManager.current

    Column(modifier.fillMaxWidth().background(Theme.statsCard)) {
        // Header
        Row(Modifier.fillMaxWidth().padding(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 14.dp), verticalAlignment = Alignment.Top) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(stringResource(R.string.chatTitle), style = Theme.Typography.Heading.hero, color = Theme.textPrimary)
                if (show != null) {
                    Text(listOfNotNull(show.displayTitle, show.hostName).joinToString(" · "), style = Theme.Typography.Copy.label, color = Theme.mutedText, maxLines = 1)
                }
            }
            Box(
                Modifier.size(32.dp).background(Theme.statsCardRaised, CircleShape).clickable(onClick = onClose),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Rounded.Close, contentDescription = stringResource(R.string.chatClose), tint = Theme.textPrimary, modifier = Modifier.size(18.dp))
            }
        }
        HorizontalDivider(color = Theme.statsCardRaised)
        state.pinned?.let {
            ChatPinnedBar(it)
            HorizontalDivider(color = Theme.statsCardRaised)
        }

        // Stream
        val listState = rememberLazyListState(initialFirstVisibleItemIndex = (rows.size + 1).coerceAtLeast(0))
        var bottomSeenId by remember { mutableLongStateOf(state.messages.lastOrNull()?.id ?: 0) }
        val atBottom = !listState.canScrollForward
        LaunchedEffect(atBottom, state.messages.lastOrNull()?.id) {
            if (atBottom) {
                bottomSeenId = state.messages.lastOrNull()?.id ?: 0
                onSeen()
            }
        }
        LaunchedEffect(rows.lastOrNull()?.key) {
            if (rows.isNotEmpty() && (atBottom || state.outgoing.isNotEmpty())) listState.animateScrollToItem(rows.size)
        }
        val unseen = state.visibleMessages.count { it.id > bottomSeenId }
        val scope = rememberCoroutineScope()
        val quietToday = state.loaded && state.outgoing.isEmpty() &&
            state.visibleMessages.none { it.createdAt.atZone(STATION_ZONE).toLocalDate() == now.atZone(STATION_ZONE).toLocalDate() }

        Box(Modifier.weight(1f).fillMaxWidth()) {
            LazyColumn(
                state = listState,
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(horizontal = 20.dp, vertical = 16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.Bottom),
            ) {
                if (!state.loaded) item("loading") {
                    if (state.loadFailed) Text(stringResource(R.string.chatLoadFailed), style = Theme.Typography.Copy.body, color = Theme.mutedText)
                    else Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = Theme.textPrimary, strokeWidth = 2.dp, modifier = Modifier.size(24.dp))
                    }
                }
                items(rows, key = { it.key }) { row ->
                    when (row) {
                        is ChatTimeline.Row.Divider -> ChatDividerRow(row.text)
                        is ChatTimeline.Row.Message -> ChatMessageRow(row.message, onLongPress = { onLongPress(row.message) })
                        is ChatTimeline.Row.Emoji -> ChatEmojiRow(row.emoji, row.count, row.names)
                        is ChatTimeline.Row.Outgoing -> ChatOutgoingRow(row.message, writer.name.orEmpty(), writer.role) { onRetry(row.message.id) }
                    }
                }
                if (quietToday) item("quiet") {
                    QuietState(writer.canWrite) { onSend(it, false) }
                }
            }
            if (!atBottom && unseen > 0) {
                Text(
                    "↓ " + L10nLogic.chatNewMessages(LocalAppLanguage.current.isEnglish, unseen),
                    style = Theme.Typography.manrope(14f, FontWeight.ExtraBold), color = Theme.textPrimary,
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(bottom = 12.dp)
                        .background(Theme.liveRed, RoundedCornerShape(50))
                        .clickable { scope.launch { listState.animateScrollToItem(rows.size) } }
                        .padding(horizontal = 16.dp, vertical = 8.dp),
                )
            }
        }
        HorizontalDivider(color = Theme.statsCardRaised)

        // Composer
        if (!writer.canWrite) {
            Column(Modifier.padding(horizontal = 20.dp).padding(top = 12.dp, bottom = 8.dp).navigationBarsPadding(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                MutedBanner(writer.mutedUntil, writer.blocked, now)
                Text(
                    stringResource(R.string.chatShowRules), style = Theme.Typography.Copy.link, color = Theme.mutedText,
                    modifier = Modifier.clickable(onClick = onRules),
                )
            }
        } else {
            Column(
                Modifier.fillMaxWidth().padding(horizontal = 20.dp).padding(top = 12.dp, bottom = 8.dp).navigationBarsPadding().imePadding(),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                if (!emojiOpen) {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        CHAT_QUICK_EMOJI.forEach { emoji ->
                            Box(
                                Modifier.weight(1f).height(36.dp).background(Theme.statsCardRaised, RoundedCornerShape(18.dp)).clickable { onSend(emoji, false) },
                                contentAlignment = Alignment.Center,
                            ) { Text(emoji, fontSize = 17.sp) }
                        }
                    }
                }
                Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Row(
                        Modifier.weight(1f).heightIn(min = 44.dp).background(Theme.statsCardRaised, RoundedCornerShape(22.dp)).padding(start = 16.dp, end = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Box(Modifier.weight(1f).padding(vertical = 11.dp)) {
                            if (draft.isEmpty()) Text(stringResource(R.string.chatPlaceholder), style = Theme.Typography.Copy.reading, color = Theme.subtleText)
                            BasicTextField(
                                value = draft,
                                onValueChange = { onDraft(it.take(500)) },
                                textStyle = Theme.Typography.Copy.reading.copy(color = Theme.textPrimary),
                                cursorBrush = SolidColor(Theme.textPrimary),
                                maxLines = 4,
                                modifier = Modifier.fillMaxWidth().focusRequester(focusRequester).onFocusChanged { if (it.isFocused) emojiOpen = false },
                            )
                        }
                        Box(
                            Modifier.size(width = 36.dp, height = 44.dp).clickable {
                                focusManager.clearFocus()
                                emojiOpen = !emojiOpen
                            },
                            contentAlignment = Alignment.Center,
                        ) {
                            Icon(
                                if (emojiOpen) Icons.Rounded.Keyboard else Icons.Rounded.SentimentSatisfied,
                                contentDescription = stringResource(R.string.chatEmoji), tint = Theme.mutedText, modifier = Modifier.size(20.dp),
                            )
                        }
                    }
                    ChatSendButton(enabled = draft.isNotBlank()) { onSend(draft, true) }
                }
                if (writer.hasName) {
                    Text(
                        buildAnnotatedString {
                            withStyle(SpanStyle(color = Theme.subtleText)) { append(stringResource(R.string.chatWritingAs) + " ") }
                            withStyle(SpanStyle(color = Theme.mutedText, fontWeight = FontWeight.ExtraBold)) { append(writer.name.orEmpty()) }
                        },
                        style = Theme.Typography.Copy.label, maxLines = 1,
                    )
                } else {
                    Text(stringResource(R.string.chatSignInToSend), style = Theme.Typography.Copy.label, color = Theme.subtleText)
                }
                AnimatedVisibility(emojiOpen, enter = fadeIn(), exit = fadeOut()) {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(stringResource(R.string.chatEmoji), style = Theme.Typography.manrope(13f, FontWeight.ExtraBold), color = Theme.mutedText)
                        LazyVerticalGrid(GridCells.Fixed(8), Modifier.height(220.dp)) {
                            items(CHAT_PICKER_EMOJI) { emoji ->
                                Box(Modifier.height(40.dp).clickable { onDraft((draft + emoji).take(500)) }, contentAlignment = Alignment.Center) {
                                    Text(emoji, fontSize = 24.sp)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

/** Nobody has written today yet (Figma F). */
@Composable
private fun QuietState(canWrite: Boolean, onSend: (String) -> Unit) {
    Column(Modifier.padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(stringResource(R.string.chatQuietTitle), style = Theme.Typography.Heading.item, color = Theme.textPrimary)
        Text(stringResource(R.string.chatQuietBody), style = Theme.Typography.Copy.body, color = Theme.mutedText)
        if (canWrite) {
            Row(Modifier.padding(top = 4.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf(stringResource(R.string.chatStarterHello), stringResource(R.string.chatStarterWhatPlayed), "🔥").forEach { text ->
                    Text(
                        text, style = Theme.Typography.manrope(14f, FontWeight.ExtraBold), color = Theme.textPrimary, maxLines = 1,
                        modifier = Modifier.background(Theme.statsCardRaised, RoundedCornerShape(50)).clickable { onSend(text) }.padding(horizontal = 14.dp, vertical = 8.dp),
                    )
                }
            }
        }
    }
}

/** Names the show in a divider from the programme: its start and title. */
fun ScheduleStore.chatShowLabel(showId: String?, title: String?, at: Instant): ChatTimeline.ShowLabel? {
    showId ?: return null
    val show = currentShow(at)?.takeIf { it.id == showId } ?: knownShow(showId)
    val name = title ?: show?.displayTitle ?: return null
    return ChatTimeline.ShowLabel(show?.start, name)
}

/**
 * The chat as a sheet over the home page, with the draft-first sign-in: a listener who
 * isn't signed in types as anyone else, and sending asks them to join (Figma H, J);
 * once they have a name the message goes out by itself.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatSheet(withKeyboard: Boolean, show: Show?, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val app = context.app
    val chat = app.chat
    val state by chat.state.collectAsState()
    val accountState by app.account.state.collectAsState()
    val now = Instant.now()
    val writer = ChatWriter.of(accountState, now)
    var draft by rememberSaveable { mutableStateOf("") }
    var pending by remember { mutableStateOf<String?>(null) }
    var joining by remember { mutableStateOf(false) }
    var rules by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val focus = remember { FocusRequester() }
    var menuMessage by remember { mutableStateOf<ChatMessage?>(null) }
    var menuStatus by remember { mutableStateOf<ChatService.UserStatus?>(null) }
    var muteTarget by remember { mutableStateOf<ChatMessage?>(null) }
    var blockTarget by remember { mutableStateOf<ChatMessage?>(null) }
    val me = (accountState as? AccountService.State.SignedIn)?.me
    val isModerator = me?.isModerator == true
    val clipboard = androidx.compose.ui.platform.LocalClipboardManager.current
    val haptics = androidx.compose.ui.platform.LocalHapticFeedback.current

    fun toast(text: String, icon: androidx.compose.ui.graphics.vector.ImageVector = Icons.Rounded.CheckCircleOutline, undo: (() -> Unit)? = null) =
        ToastCenter.show(ToastCenter.Toast(icon, text, if (undo != null) context.getString(R.string.chatUndo) else null, undo))

    fun run(work: suspend () -> Unit) {
        scope.launch {
            try {
                work()
            } catch (e: AccountError) {
                toast(context.getString(e.messageRes), Icons.Rounded.ErrorOutline)
            }
        }
    }

    fun openMenu(message: ChatMessage) {
        if (message.isDeleted) return
        haptics.performHapticFeedback(androidx.compose.ui.hapticfeedback.HapticFeedbackType.LongPress)
        menuStatus = null
        menuMessage = message
        val author = message.userId
        if (isModerator && author != null && author != me?.userId) {
            scope.launch { menuStatus = runCatching { chat.status(author) }.getOrNull() }
        }
    }

    fun mute(message: ChatMessage, minutes: Int) {
        val author = message.userId ?: return
        val name = message.authorName ?: context.getString(R.string.deletedAccount)
        run {
            val until = chat.mute(author, minutes, message) ?: Instant.now().plusSeconds(minutes * 60L)
            val (day, time) = cz.slowdownradijo.app.profile.dayAndTime(until, Instant.now(), context)
            toast(context.getString(R.string.chatMutedToast, name, day, time), Icons.AutoMirrored.Rounded.VolumeOff) {
                run { chat.unmute(author) }
            }
        }
    }

    fun perform(action: ChatMenuAction, message: ChatMessage) {
        val name = message.authorName ?: context.getString(R.string.deletedAccount)
        val author = message.userId
        when (action) {
            ChatMenuAction.COPY -> clipboard.setText(androidx.compose.ui.text.AnnotatedString(message.body.orEmpty()))
            ChatMenuAction.PIN -> run {
                chat.pin(message)
                toast(context.getString(R.string.chatPinnedToast), Icons.Rounded.PushPin)
            }
            ChatMenuAction.UNPIN -> run {
                chat.unpin()
                toast(context.getString(R.string.chatUnpinnedToast), Icons.Rounded.PushPin)
            }
            ChatMenuAction.DELETE -> run {
                chat.delete(message)
                toast(context.getString(R.string.chatDeletedToast), Icons.Rounded.DeleteOutline) { run { chat.restore(message) } }
            }
            ChatMenuAction.MUTE -> muteTarget = message
            ChatMenuAction.UNMUTE -> if (author != null) run {
                chat.unmute(author)
                toast(context.getString(R.string.chatUnmutedToast, name), Icons.AutoMirrored.Rounded.VolumeUp)
            }
            ChatMenuAction.BLOCK -> blockTarget = message
            ChatMenuAction.REPORT -> if (writer.signedIn) run {
                chat.report(message)
                toast(context.getString(R.string.chatReportedToast), Icons.Outlined.Flag)
            } else {
                pending = null
                joining = true
            }
            ChatMenuAction.HIDE -> if (author != null) run {
                chat.hide(author)
                toast(context.getString(R.string.chatHiddenToast, name), Icons.Outlined.VisibilityOff) { run { chat.unhide(author) } }
            }
        }
    }

    fun send(text: String, announce: Boolean) {
        scope.launch {
            try {
                chat.send(text, app.schedule.currentShow() ?: show)
                if (announce) writer.name?.let { name ->
                    ToastCenter.show(ToastCenter.Toast(Icons.Rounded.CheckCircleOutline, context.getString(R.string.chatSentAs, name)))
                }
            } catch (e: AccountError) {
                when (e) {
                    AccountError.NicknameRequired -> {
                        pending = text
                        joining = true
                    }
                    AccountError.Offline -> Unit // shown on the message itself
                    else -> ToastCenter.show(ToastCenter.Toast(Icons.Rounded.ErrorOutline, context.getString(e.messageRes)))
                }
            }
        }
    }

    fun submit(raw: String, clearsDraft: Boolean) {
        val text = raw.trim()
        if (text.isEmpty()) return
        if (!writer.hasName) {
            pending = text
            joining = true
            return
        }
        if (clearsDraft) draft = ""
        send(text, announce = false)
    }

    ModalBottomSheet(
        onDismissRequest = {
            chat.markSeen()
            onDismiss()
        },
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = Theme.statsCard,
        shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
    ) {
        // Over the sheet, where the screen's own toasts can't be seen.
        cz.slowdownradijo.app.ui.components.ToastHost { ChatContent(
            state = state, show = show, writer = writer, draft = draft, onDraft = { draft = it },
            onSend = ::submit,
            onRetry = { id -> scope.launch { runCatching { chat.retry(id) } } },
            onClose = {
                chat.markSeen()
                onDismiss()
            },
            onRules = { rules = true },
            onSeen = chat::markSeen,
            showLabel = app.schedule::chatShowLabel,
            modifier = Modifier.fillMaxHeight(0.78f),
            now = now,
            focusRequester = focus,
            onLongPress = ::openMenu,
        ) }
    }

    menuMessage?.let { message ->
        ModalBottomSheet(
            onDismissRequest = { menuMessage = null },
            containerColor = Theme.statsCard,
            shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
        ) {
            ChatMessageMenu(
                message,
                ChatMenu.actions(message, if (writer.signedIn) me?.userId else null, isModerator, state.pinned?.id == message.id, menuStatus),
                menuStatus, Instant.now(),
            ) { action ->
                menuMessage = null
                perform(action, message)
            }
        }
    }
    muteTarget?.let { message ->
        ModalBottomSheet(
            onDismissRequest = { muteTarget = null },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
            containerColor = Theme.statsCard,
            shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
        ) {
            ChatMuteContent(message.authorName ?: stringResource(R.string.deletedAccount), onMute = { minutes ->
                muteTarget = null
                mute(message, minutes)
            }, onCancel = { muteTarget = null })
        }
    }
    blockTarget?.let { message ->
        val name = message.authorName ?: stringResource(R.string.deletedAccount)
        ModalBottomSheet(
            onDismissRequest = { blockTarget = null },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
            containerColor = Theme.statsCard,
            shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
        ) {
            ChatBlockContent(name, onBlock = {
                blockTarget = null
                val author = message.userId ?: return@ChatBlockContent
                run {
                    chat.block(author, message)
                    toast(context.getString(R.string.chatBlockedToast, name), Icons.Rounded.Block)
                }
            }, onCancel = { blockTarget = null })
        }
    }
    LaunchedEffect(Unit) {
        if (withKeyboard) {
            kotlinx.coroutines.delay(350)
            runCatching { focus.requestFocus() }
        }
    }

    if (joining) {
        ChatJoinSheet(
            onReady = {
                joining = false
                val text = pending ?: return@ChatJoinSheet
                pending = null
                if (draft.trim() == text) draft = ""
                send(text, announce = true)
            },
            onDismiss = {
                joining = false
                pending = null
            },
            onRules = { rules = true },
        )
    }
    if (rules) {
        ModalBottomSheet(onDismissRequest = { rules = false }, containerColor = Theme.background) {
            ChatRulesScreen(back = { rules = false })
        }
    }
}

/** "Připoj se do chatu" (Figma H), then the nickname (J) for a new account. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatJoinSheet(onReady: () -> Unit, onDismiss: () -> Unit, onRules: () -> Unit) {
    val context = LocalContext.current
    val account = context.app.account
    val state by account.state.collectAsState()
    var busy by remember { mutableStateOf(false) }
    var email by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val actions = signInActions(context, scope, account, setBusy = { busy = it }, onEmail = { email = true })
    val ready = (state as? AccountService.State.SignedIn)?.me?.chatName != null

    LaunchedEffect(Unit) {
        snapshotFlow { (account.state.value as? AccountService.State.SignedIn)?.me?.chatName != null }
            .distinctUntilChanged()
            .collect { if (it) onReady() }
    }
    BackHandler(email) { email = false }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = Theme.statsCard,
        shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
    ) {
        ChatJoinContent(state, ready, busy, email, actions, onBackFromEmail = { email = false }, onDismiss = onDismiss, onRules = onRules)
    }
}

@Composable
fun ChatJoinContent(
    state: AccountService.State,
    ready: Boolean,
    busy: Boolean,
    email: Boolean,
    actions: ProfileActions,
    onBackFromEmail: () -> Unit,
    onDismiss: () -> Unit,
    onRules: () -> Unit,
) {
    val context = LocalContext.current
    val signedIn = state as? AccountService.State.SignedIn
    when {
        signedIn != null && signedIn.me != null && !ready -> Column(Modifier.padding(horizontal = 20.dp).padding(bottom = 24.dp).navigationBarsPadding().imePadding()) {
            NicknameSetup(actions)
        }
        signedIn != null -> Box(Modifier.fillMaxWidth().padding(32.dp), contentAlignment = Alignment.Center) {
            CircularProgressIndicator(color = Theme.textPrimary, strokeWidth = 2.dp, modifier = Modifier.size(28.dp))
        }
        email -> Box(Modifier.fillMaxHeight(0.9f).imePadding()) {
            EmailSignInScreen(
                sendCode = context.app.account::sendEmailCode,
                verify = context.app.account::verifyEmailCode,
                back = onBackFromEmail,
                onSignedIn = onBackFromEmail,
            )
        }
        else -> JoinButtons(busy, actions, onDismiss, onRules)
    }
}

@Composable
fun JoinButtons(busy: Boolean, actions: ProfileActions, onDismiss: () -> Unit, onRules: () -> Unit) {
    Column(
        Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(top = 8.dp, bottom = 24.dp).navigationBarsPadding(),
        verticalArrangement = Arrangement.spacedBy(Theme.Spacing.lg),
    ) {
        ProfileHeading(stringResource(R.string.chatJoinTitle), stringResource(R.string.chatJoinBody), hero = true)
        SignInButtons(busy, actions.onApple, actions.onGoogle, actions.onEmail)
        Text(
            stringResource(R.string.chatNotNow), style = Theme.Typography.Copy.link, color = Theme.mutedText, textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth().clickable(onClick = onDismiss).padding(vertical = 4.dp),
        )
        Text(
            stringResource(R.string.chatJoinLegal), style = Theme.Typography.Copy.label, color = Theme.subtleText, textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth().clickable(onClick = onRules),
        )
    }
}


/** Opening a DJ invite link (Figma P1–P3), shown over any tab. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HostInviteSheet(onOpenChat: () -> Unit) {
    val context = LocalContext.current
    val app = context.app
    val code by app.chat.pendingInvite.collectAsState()
    val current = code ?: return
    val account = app.account
    val accountState by account.state.collectAsState()
    var phase by remember(current) { mutableStateOf<InvitePhase>(InvitePhase.Loading) }
    var info by remember(current) { mutableStateOf<ChatService.InviteInfo?>(null) }
    var busy by remember { mutableStateOf(false) }
    var email by remember { mutableStateOf(false) }
    var claiming by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val actions = signInActions(context, scope, account, setBusy = { busy = it }, onEmail = { email = true })
    val signedIn = accountState is AccountService.State.SignedIn

    LaunchedEffect(current) {
        phase = try {
            info = app.chat.inviteInfo(current)
            if (info == null) InvitePhase.Invalid(otherHost = false) else InvitePhase.Ready(info, linking = false)
        } catch (e: AccountError) {
            // Offline, or the server without host_invite_info (021): let the claim decide.
            InvitePhase.Ready(null, linking = false)
        }
    }
    LaunchedEffect(phase is InvitePhase.Ready, signedIn) {
        if (phase !is InvitePhase.Ready || !signedIn || claiming) return@LaunchedEffect
        claiming = true
        email = false
        phase = InvitePhase.Ready(info, linking = true)
        phase = try {
            account.claimHostInvite(current)
            InvitePhase.Done(account.me?.hostName ?: info?.hostName ?: "DJ")
        } catch (e: AccountError) {
            when (e) {
                AccountError.InviteOtherHost -> InvitePhase.Invalid(otherHost = true)
                AccountError.InviteInvalid -> InvitePhase.Invalid(otherHost = false)
                else -> {
                    ToastCenter.show(ToastCenter.Toast(Icons.Rounded.ErrorOutline, context.getString(e.messageRes)))
                    InvitePhase.Ready(info, linking = false)
                }
            }
        } finally {
            claiming = false
        }
    }
    BackHandler(email) { email = false }

    ModalBottomSheet(
        onDismissRequest = app.chat::clearInvite,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = Theme.statsCard,
        shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
    ) {
        if (email && !signedIn) {
            Box(Modifier.fillMaxHeight(0.9f).imePadding()) {
                EmailSignInScreen(
                    sendCode = account::sendEmailCode,
                    verify = account::verifyEmailCode,
                    back = { email = false },
                    onSignedIn = { email = false },
                )
            }
        } else {
            HostInviteContent(phase, busy, actions, onOpenChat = {
                app.chat.clearInvite()
                onOpenChat()
            }, onClose = app.chat::clearInvite)
        }
    }
}
