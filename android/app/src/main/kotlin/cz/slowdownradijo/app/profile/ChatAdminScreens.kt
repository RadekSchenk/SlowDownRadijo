package cz.slowdownradijo.app.profile

import android.content.ClipData
import android.content.Intent
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.ContentCopy
import androidx.compose.material.icons.rounded.ErrorOutline
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.ClipEntry
import androidx.compose.ui.platform.LocalClipboard
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import cz.slowdownradijo.app.R
import cz.slowdownradijo.app.account.AccountError
import cz.slowdownradijo.app.analytics.AnalyticsEvent
import cz.slowdownradijo.app.app
import cz.slowdownradijo.app.chat.ChatAdmin
import cz.slowdownradijo.app.ui.components.PrimaryActionButton
import cz.slowdownradijo.app.ui.components.SecondaryActionButton
import cz.slowdownradijo.app.ui.components.ToastCenter
import cz.slowdownradijo.app.ui.theme.Theme
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId

/** The superadmin's pages inside Profil (Figma Profil A1–A6). */
sealed interface AdminRoute {
    data object Moderators : AdminRoute
    data class Invite(val preselected: String?) : AdminRoute
    data class InviteReady(val invite: ChatAdmin.Invite, val name: String) : AdminRoute
    data class Moderator(val hostId: String) : AdminRoute
    data object Admins : AdminRoute
    data object AddAdmin : AdminRoute
}

private fun shortDate(at: Instant?): String = at?.atZone(ZoneId.of("Europe/Prague"))?.let { "${it.dayOfMonth}. ${it.monthValue}. ${it.year}" }.orEmpty()

@Composable
private fun AdminBody(text: String) = Text(text, style = Theme.Typography.Copy.body, color = Theme.mutedText)

@Composable
private fun AdminRow(title: String, subtitle: String?, subtitleColor: Color = Theme.subtleText, chevron: Boolean = true, tag: Boolean = false, onClick: (() -> Unit)?) {
    Column {
        Row(
            Modifier.fillMaxWidth().then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier).padding(vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(title, style = Theme.Typography.Heading.item, color = Theme.textPrimary)
                    if (tag) DjTag()
                }
                if (subtitle != null) Text(subtitle, style = Theme.Typography.Copy.label, color = subtitleColor)
            }
            if (chevron) Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, contentDescription = null, tint = Theme.subtleText, modifier = Modifier.size(22.dp))
        }
        HorizontalDivider(color = Theme.hairline(0.08f))
    }
}

@Composable
private fun RadioRow(title: String, subtitle: String?, selected: Boolean, disabled: Boolean, onSelect: () -> Unit) {
    Column(Modifier.alpha(if (disabled) 0.45f else 1f)) {
        Row(
            Modifier.fillMaxWidth().selectable(selected = selected, enabled = !disabled, role = Role.RadioButton, onClick = onSelect).padding(vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            RadioButton(selected = selected, onClick = null, colors = RadioButtonDefaults.colors(selectedColor = Theme.liveRed, unselectedColor = Theme.mutedText))
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(title, style = Theme.Typography.Heading.item, color = Theme.textPrimary)
                if (!subtitle.isNullOrEmpty()) Text(subtitle, style = Theme.Typography.Copy.label, color = Theme.subtleText, maxLines = 2)
            }
        }
        HorizontalDivider(color = Theme.hairline(0.08f))
    }
}

/** One row of "Moderátoři" (A1). */
data class ModeratorRow(val id: String, val name: String, val status: String, val pending: Boolean, val linked: Boolean)

@Composable
fun AdminModeratorsScreen(rows: List<ModeratorRow>, onOpen: (String) -> Unit, onInvite: () -> Unit, back: () -> Unit) {
    SubPage(stringResource(R.string.adminModerators), back) {
        AdminBody(stringResource(R.string.adminModeratorsBody))
        Column {
            rows.forEach { row ->
                AdminRow(row.name, row.status, if (row.pending) Theme.gold else Theme.subtleText, tag = row.linked) { onOpen(row.id) }
            }
        }
        PrimaryActionButton(stringResource(R.string.adminInviteModerator), onClick = onInvite)
    }
}

@Composable
fun AdminInviteScreen(
    hosts: List<ChatAdmin.ProgrammeHost>,
    linked: Set<String>,
    preselected: String?,
    creating: Boolean,
    onCreate: (id: String, name: String, fromProgramme: Boolean) -> Unit,
    back: () -> Unit,
) {
    val guest = "_guest"
    var selected by remember { mutableStateOf(preselected) }
    var guestName by remember { mutableStateOf("") }
    SubPage(stringResource(R.string.adminInviteModerator), back) {
        AdminBody(stringResource(R.string.adminInviteBody))
        Column {
            hosts.forEach { host ->
                val isLinked = host.id in linked
                RadioRow(host.name, if (isLinked) stringResource(R.string.adminAlreadyLinked) else host.shows.joinToString(", "), selected == host.id, isLinked) { selected = host.id }
            }
            RadioRow(stringResource(R.string.adminGuestHost), stringResource(R.string.adminGuestHostBody), selected == guest, false) { selected = guest }
            AnimatedVisibility(selected == guest) {
                BasicTextField(
                    value = guestName, onValueChange = { guestName = it.take(60) },
                    textStyle = Theme.Typography.Copy.reading.copy(color = Theme.textPrimary), cursorBrush = SolidColor(Theme.textPrimary), singleLine = true,
                    modifier = Modifier.fillMaxWidth().padding(top = 12.dp).background(Theme.statsCardRaised, RoundedCornerShape(10.dp)).padding(horizontal = 16.dp, vertical = 14.dp),
                    decorationBox = { inner ->
                        if (guestName.isEmpty()) Text(stringResource(R.string.adminGuestNamePlaceholder), style = Theme.Typography.Copy.reading, color = Theme.subtleText)
                        inner()
                    },
                )
            }
        }
        val canCreate = when (selected) {
            null -> false
            guest -> guestName.trim().length >= 2
            else -> true
        }
        PrimaryActionButton(stringResource(R.string.adminCreateInvite), enabled = canCreate && !creating) {
            val id = selected ?: return@PrimaryActionButton
            if (id == guest) onCreate(ChatAdmin.hostId(guestName.trim()), guestName.trim(), false)
            else onCreate(id, hosts.first { it.id == id }.name, true)
        }
    }
}

@Composable
fun AdminInviteReadyScreen(invite: ChatAdmin.Invite, name: String, onShare: () -> Unit, onCopy: () -> Unit, back: () -> Unit) {
    var copied by remember { mutableStateOf(false) }
    var appeared by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { appeared = true }
    LaunchedEffect(copied) { if (copied) { delay(2000); copied = false } }
    SubPage(stringResource(R.string.adminInviteReady), back) {
        AdminBody(stringResource(R.string.adminInviteReadyBody, name))
        AnimatedVisibility(appeared, enter = fadeIn(tween(300)) + scaleIn(tween(300), initialScale = 0.97f)) {
            Column(Modifier.fillMaxWidth().background(Theme.statsCardRaised, RoundedCornerShape(12.dp)).padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(invite.url.removePrefix("https://"), style = Theme.Typography.manrope(16f, FontWeight.Bold), color = Theme.textPrimary)
                Text(stringResource(R.string.adminInviteValidity, shortDate(invite.expiresAt)), style = Theme.Typography.Copy.label, color = Theme.subtleText)
            }
        }
        PrimaryActionButton(stringResource(R.string.adminShareLink), onClick = onShare)
        Row(
            Modifier.fillMaxWidth().height(48.dp).background(Theme.hairline(0.08f), RoundedCornerShape(10.dp)).clickable { onCopy(); copied = true },
            horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically,
        ) {
            AnimatedContent(copied, transitionSpec = { (fadeIn(tween(200)) + scaleIn(tween(200), initialScale = 0.6f)) togetherWith fadeOut(tween(120)) }, label = "copy") { done ->
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Icon(if (done) Icons.Rounded.Check else Icons.Rounded.ContentCopy, contentDescription = null, tint = Theme.textPrimary, modifier = Modifier.size(18.dp))
                    Text(stringResource(if (done) R.string.adminCopied else R.string.adminCopyLink), style = Theme.Typography.Copy.button, color = Theme.textPrimary)
                }
            }
        }
    }
}

@Composable
fun AdminModeratorDetailScreen(
    name: String,
    shows: List<String>,
    host: ChatAdmin.Host?,
    working: Boolean,
    onNewInvite: () -> Unit,
    onUnlink: () -> Unit,
    back: () -> Unit,
) {
    SubPage(name, back) {
        Column {
            InfoRow(stringResource(R.string.adminShows), shows.joinToString(", ").ifEmpty { "—" })
            InfoRow(
                stringResource(R.string.adminAccount),
                when {
                    host?.linked == true -> stringResource(R.string.adminLinkedOn, shortDate(host.linkedAt))
                    host?.inviteExpiresAt != null -> stringResource(R.string.adminInvitePending, shortDate(host.inviteExpiresAt))
                    else -> stringResource(R.string.adminNoAccount)
                },
            )
            InfoRow(stringResource(R.string.adminWritesAs), name)
        }
        Column {
            val pendingOrLinked = host?.linked == true || host?.inviteExpiresAt != null
            AdminRow(stringResource(if (pendingOrLinked) R.string.adminSendNewInvite else R.string.adminCreateInvite), null, onClick = if (working) null else onNewInvite)
            if (host?.linked == true) {
                Text(
                    stringResource(R.string.adminUnlink), style = Theme.Typography.Heading.item, color = Theme.liveRed,
                    modifier = Modifier.fillMaxWidth().clickable(onClick = onUnlink).padding(vertical = 12.dp),
                )
            }
        }
        if (host?.linked == true) Text(stringResource(R.string.adminUnlinkNote), style = Theme.Typography.Copy.label, color = Theme.subtleText)
    }
}

@Composable
private fun InfoRow(title: String, value: String) {
    Column {
        Row(Modifier.fillMaxWidth().padding(vertical = 12.dp), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            Text(title, style = Theme.Typography.Heading.item, color = Theme.textPrimary, modifier = Modifier.weight(1f))
            Text(value, style = Theme.Typography.Copy.body, color = Theme.mutedText)
        }
        HorizontalDivider(color = Theme.hairline(0.08f))
    }
}

@Composable
fun AdminAdminsScreen(admins: List<ChatAdmin.Admin>, onRemove: (ChatAdmin.Admin) -> Unit, onAdd: () -> Unit, back: () -> Unit) {
    SubPage(stringResource(R.string.adminAdmins), back) {
        AdminBody(stringResource(R.string.adminAdminsBody))
        Column {
            admins.forEach { admin ->
                val removable = !admin.isSuperadmin && !admin.isMe
                AdminRow(
                    admin.nickname.orEmpty() + if (admin.isMe) " (${stringResource(R.string.adminYou)})" else "",
                    if (admin.isSuperadmin) stringResource(R.string.adminSuperadmin) else stringResource(R.string.adminAdminSince, shortDate(admin.adminSince)),
                    if (admin.isSuperadmin) Theme.liveRed else Theme.subtleText,
                    chevron = removable,
                    onClick = if (removable) ({ onRemove(admin) }) else null,
                )
            }
        }
        PrimaryActionButton(stringResource(R.string.adminAddAdmin), onClick = onAdd)
    }
}

@Composable
fun AdminAddAdminScreen(
    query: String,
    onQuery: (String) -> Unit,
    results: List<ChatAdmin.FoundUser>,
    working: Boolean,
    onAdd: (ChatAdmin.FoundUser) -> Unit,
    back: () -> Unit,
) {
    var selected by remember { mutableStateOf<String?>(null) }
    SubPage(stringResource(R.string.adminAddAdmin), back) {
        AdminBody(stringResource(R.string.adminAddAdminBody))
        Row(
            Modifier.fillMaxWidth().background(Theme.statsCardRaised, RoundedCornerShape(10.dp)).padding(horizontal = 16.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Icon(Icons.Rounded.Search, contentDescription = null, tint = Theme.mutedText, modifier = Modifier.size(18.dp))
            BasicTextField(
                value = query, onValueChange = onQuery, singleLine = true,
                textStyle = Theme.Typography.Copy.reading.copy(color = Theme.textPrimary), cursorBrush = SolidColor(Theme.textPrimary),
                modifier = Modifier.weight(1f),
                decorationBox = { inner ->
                    if (query.isEmpty()) Text(stringResource(R.string.adminSearchPlaceholder), style = Theme.Typography.Copy.reading, color = Theme.subtleText)
                    inner()
                },
            )
        }
        Column {
            results.forEach { user ->
                val disabled = user.registeredAt == null || user.isAdmin
                RadioRow(
                    user.nickname.orEmpty(),
                    when {
                        user.isAdmin -> stringResource(R.string.adminAlreadyAdmin)
                        user.registeredAt != null -> stringResource(R.string.slowriderSince, shortDate(user.registeredAt))
                        else -> stringResource(R.string.adminNotRegistered)
                    },
                    selected == user.userId, disabled,
                ) { selected = user.userId }
            }
        }
        PrimaryActionButton(stringResource(R.string.adminMakeAdmin), enabled = selected != null && !working) {
            results.firstOrNull { it.userId == selected }?.let(onAdd)
        }
    }
}

/** The superadmin's pages with their data and actions, inside the Profil tab. */
@Composable
fun AdminFlow(route: AdminRoute, navigate: (AdminRoute?) -> Unit) {
    val context = LocalContext.current
    val app = context.app
    val admin = app.chatAdmin
    val overview by admin.overview.collectAsState()
    val days by app.schedule.days.collectAsState()
    val scope = rememberCoroutineScope()
    var working by remember { mutableStateOf(false) }
    val clipboard = LocalClipboard.current
    fun toastError(e: AccountError) = ToastCenter.show(ToastCenter.Toast(Icons.Rounded.ErrorOutline, context.getString(e.messageRes)))
    val programme = remember(days) { ChatAdmin.programmeHosts(days, app.schedule.catalog) }

    LaunchedEffect(route) {
        if (route is AdminRoute.Moderators || route is AdminRoute.Admins || overview == null) {
            try { admin.reload() } catch (e: AccountError) { toastError(e) }
        }
    }

    fun create(id: String, name: String, fromProgramme: Boolean) {
        working = true
        scope.launch {
            try {
                val invite = admin.createInvite(id, name)
                app.analytics.track(AnalyticsEvent.AdminInviteCreated(fromProgramme))
                navigate(AdminRoute.InviteReady(invite, name))
            } catch (e: AccountError) { toastError(e) } finally { working = false }
        }
    }

    when (route) {
        AdminRoute.Moderators -> {
            val hosts = overview?.hosts.orEmpty()
            val ids = (programme.map { it.id } + hosts.map { it.hostId }).distinct()
            val rows = ids.map { id ->
                val p = programme.firstOrNull { it.id == id }
                val h = hosts.firstOrNull { it.hostId == id }
                val name = h?.displayName ?: p?.name ?: id
                val shows = p?.shows.orEmpty().joinToString(", ")
                when {
                    h?.linked == true -> ModeratorRow(id, name, if (shows.isEmpty()) stringResource(R.string.adminLinked) else "${stringResource(R.string.adminLinked)} · $shows", false, true)
                    h?.inviteExpiresAt != null -> ModeratorRow(id, name, stringResource(R.string.adminInvitePending, shortDate(h.inviteExpiresAt)), true, false)
                    else -> ModeratorRow(id, name, stringResource(R.string.adminNoAccount), false, false)
                }
            }.sortedWith(compareBy({ !it.linked }, { it.name.lowercase() }))
            AdminModeratorsScreen(rows, onOpen = { navigate(AdminRoute.Moderator(it)) }, onInvite = { navigate(AdminRoute.Invite(null)) }, back = { navigate(null) })
        }
        is AdminRoute.Invite -> AdminInviteScreen(
            programme, overview?.hosts.orEmpty().filter { it.linked }.map { it.hostId }.toSet(), route.preselected, working,
            onCreate = ::create, back = { navigate(AdminRoute.Moderators) },
        )
        is AdminRoute.InviteReady -> AdminInviteReadyScreen(
            route.invite, route.name,
            onShare = {
                app.analytics.track(AnalyticsEvent.AdminInviteShared("share"))
                val send = Intent(Intent.ACTION_SEND).setType("text/plain")
                    .putExtra(Intent.EXTRA_TEXT, context.getString(R.string.adminInviteShareMessage, route.name) + "\n" + route.invite.url)
                runCatching { context.startActivity(Intent.createChooser(send, null)) }
            },
            onCopy = {
                app.analytics.track(AnalyticsEvent.AdminInviteShared("copy"))
                scope.launch { clipboard.setClipEntry(ClipEntry(ClipData.newPlainText("invite", route.invite.url))) }
            },
            back = { navigate(AdminRoute.Moderators) },
        )
        is AdminRoute.Moderator -> {
            val p = programme.firstOrNull { it.id == route.hostId }
            val h = overview?.hosts?.firstOrNull { it.hostId == route.hostId }
            val name = h?.displayName ?: p?.name ?: route.hostId
            var confirming by remember { mutableStateOf(false) }
            AdminModeratorDetailScreen(
                name, p?.shows.orEmpty(), h, working,
                onNewInvite = { create(route.hostId, name, p != null) },
                onUnlink = { confirming = true },
                back = { navigate(AdminRoute.Moderators) },
            )
            if (confirming) ConfirmDialog(
                stringResource(R.string.adminUnlinkConfirm, name), stringResource(R.string.adminUnlinkNote), stringResource(R.string.adminUnlink),
                destructive = true, onDismiss = { confirming = false },
            ) {
                confirming = false
                scope.launch {
                    try {
                        admin.unlink(route.hostId)
                        app.analytics.track(AnalyticsEvent.AdminHostUnlinked())
                    } catch (e: AccountError) { toastError(e) }
                }
            }
        }
        AdminRoute.Admins -> {
            var removing by remember { mutableStateOf<ChatAdmin.Admin?>(null) }
            AdminAdminsScreen(overview?.admins.orEmpty(), onRemove = { removing = it }, onAdd = { navigate(AdminRoute.AddAdmin) }, back = { navigate(null) })
            removing?.let { user ->
                ConfirmDialog(
                    stringResource(R.string.adminRemoveAdmin, user.nickname.orEmpty()), "", stringResource(R.string.adminRemove),
                    destructive = true, onDismiss = { removing = null },
                ) {
                    removing = null
                    scope.launch {
                        try {
                            admin.setAdmin(user.userId, false)
                            app.analytics.track(AnalyticsEvent.AdminAdminsChanged("remove"))
                        } catch (e: AccountError) { toastError(e) }
                    }
                }
            }
        }
        AdminRoute.AddAdmin -> {
            var query by remember { mutableStateOf("") }
            var results by remember { mutableStateOf<List<ChatAdmin.FoundUser>>(emptyList()) }
            LaunchedEffect(query) {
                val q = query.trim()
                if (q.length < 2) { results = emptyList(); return@LaunchedEffect }
                delay(300)
                results = runCatching { admin.findUsers(q) }.getOrDefault(emptyList())
            }
            AdminAddAdminScreen(query, { query = it }, results, working, onAdd = { user ->
                working = true
                scope.launch {
                    try {
                        admin.setAdmin(user.userId, true)
                        app.analytics.track(AnalyticsEvent.AdminAdminsChanged("add"))
                        navigate(AdminRoute.Admins)
                    } catch (e: AccountError) { toastError(e) } finally { working = false }
                }
            }, back = { navigate(AdminRoute.Admins) })
        }
    }
}
