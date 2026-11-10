package cz.slowdownradijo.app.menu

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Chat
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Email
import androidx.compose.material.icons.rounded.Newspaper
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.Canvas
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import cz.slowdownradijo.app.R
import cz.slowdownradijo.app.l10n.AppLanguage
import cz.slowdownradijo.app.l10n.LocalAppLanguage
import cz.slowdownradijo.app.ui.components.HeaderIconButton
import cz.slowdownradijo.app.ui.components.ListDivider
import cz.slowdownradijo.app.ui.components.ListRow
import cz.slowdownradijo.app.ui.components.ListRowChevron
import cz.slowdownradijo.app.ui.components.ListRowIcon
import cz.slowdownradijo.app.ui.theme.Theme

/** The pages the menu can show over itself. */
sealed interface MenuPage {
    data object Settings : MenuPage
    data object ShowReminders : MenuPage
    data object News : MenuPage
    data class NewsDetail(val id: Int) : MenuPage
    data object Feedback : MenuPage
}

/** What the menu's pages need from the app, so screenshot tests can stand them up alone. */
class MenuPages(
    val settings: @Composable (open: (MenuPage) -> Unit, back: () -> Unit) -> Unit,
    val showReminders: @Composable (back: () -> Unit) -> Unit,
    val news: @Composable (open: (MenuPage) -> Unit, back: () -> Unit) -> Unit,
    val newsDetail: @Composable (id: Int, back: () -> Unit) -> Unit,
    val feedback: @Composable (back: () -> Unit) -> Unit,
)

/**
 * The menu (`HubView.swift`): the language switch, WhatsApp, Settings,
 * News and Feedback, and the station's social links. Its pages open over
 * it, and back goes back through them.
 */
@Composable
fun HubScreen(onLanguage: (AppLanguage) -> Unit, onClose: () -> Unit, pages: MenuPages, onLinkOpened: (String) -> Unit = {}) {
    val stack = remember { mutableStateListOf<MenuPage>() }
    val back: () -> Unit = { if (stack.isNotEmpty()) stack.removeAt(stack.lastIndex) else onClose() }
    val open: (MenuPage) -> Unit = { stack.add(it) }
    BackHandler(onBack = back)

    AnimatedContent(
        targetState = stack.lastOrNull(),
        transitionSpec = {
            val forward = (targetState != null && initialState == null) || stack.size > 1 && targetState == stack.last()
            if (forward) (slideInHorizontally { it / 3 } + fadeIn()) togetherWith fadeOut()
            else fadeIn() togetherWith (slideOutHorizontally { it / 3 } + fadeOut())
        },
        modifier = Modifier
            .fillMaxSize()
            .background(Theme.background),
        label = "menu",
    ) { page ->
        Box(Modifier.fillMaxSize().background(Theme.background).safeDrawingPadding()) {
            when (page) {
                null -> HubRoot(onLanguage, onClose, open, onLinkOpened)
                MenuPage.Settings -> pages.settings(open, back)
                MenuPage.ShowReminders -> pages.showReminders(back)
                MenuPage.News -> pages.news(open, back)
                is MenuPage.NewsDetail -> pages.newsDetail(page.id, back)
                MenuPage.Feedback -> pages.feedback(back)
            }
        }
    }
}

private const val WHATSAPP = "https://wa.me/420720600811"

@Composable
fun HubRoot(onLanguage: (AppLanguage) -> Unit, onClose: () -> Unit, open: (MenuPage) -> Unit, onLinkOpened: (String) -> Unit = {}) {
    val context = LocalContext.current
    fun openUrl(url: String) = runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) }
    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp)
            .padding(top = 20.dp, bottom = Theme.Spacing.xl),
        verticalArrangement = Arrangement.spacedBy(Theme.Spacing.xl),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(Theme.Spacing.md)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(R.string.hubTitle), style = Theme.Typography.Heading.page, color = Theme.textPrimary)
                Spacer(Modifier.weight(1f))
                HeaderIconButton(Icons.Rounded.Close, stringResource(R.string.close), onClose)
            }
            LanguageSwitch(onLanguage)
        }

        Column {
            ListDivider()
            ListRow(stringResource(R.string.hubWhatsAppRow), stringResource(R.string.hubWhatsAppRowSubtitle), onClick = {
                onLinkOpened("whatsapp"); openUrl(WHATSAPP)
            }, leading = { ListRowIcon(Icons.Rounded.Chat) }) { ListRowChevron() }
            ListDivider()
            ListRow(stringResource(R.string.hubSettingsRow), stringResource(R.string.hubSettingsRowSubtitle), onClick = { open(MenuPage.Settings) },
                leading = { ListRowIcon(Icons.Rounded.Settings) }) { ListRowChevron() }
            ListDivider()
            ListRow(stringResource(R.string.hubNewsRow), stringResource(R.string.hubNewsRowSubtitle), onClick = { open(MenuPage.News) },
                leading = { ListRowIcon(Icons.Rounded.Newspaper) }) { ListRowChevron() }
            ListDivider()
            ListRow(stringResource(R.string.hubFeedbackRow), stringResource(R.string.hubFeedbackRowSubtitle), onClick = { open(MenuPage.Feedback) },
                leading = { ListRowIcon(Icons.Rounded.Email) }) { ListRowChevron() }
        }

        Column(verticalArrangement = Arrangement.spacedBy(Theme.Spacing.md)) {
            Text(stringResource(R.string.hubSocialTitle), style = Theme.Typography.Heading.section, color = Theme.textPrimary)
            SocialLinks { label, url -> onLinkOpened(label.lowercase()); openUrl(url) }
        }
    }
}

/** Čeština | English, the app's own language (`HubView.languageSwitch`). */
@Composable
private fun LanguageSwitch(onLanguage: (AppLanguage) -> Unit) {
    val current = LocalAppLanguage.current
    val title = stringResource(R.string.settingsLanguageTitle)
    Row(
        Modifier
            .fillMaxWidth()
            .background(Theme.statsCard, RoundedCornerShape(12.dp))
            .padding(3.dp)
            .semantics { contentDescription = title },
        horizontalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        for (language in AppLanguage.entries) {
            val isSelected = language == current
            Box(
                Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(9.dp))
                    .background(if (isSelected) Theme.statsCardRaised else Theme.statsCard)
                    .clickable(role = Role.RadioButton) { if (!isSelected) onLanguage(language) }
                    .semantics { selected = isSelected }
                    .padding(vertical = 9.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    if (language == AppLanguage.CS) "Čeština" else "English",
                    style = Theme.Typography.manrope(14f, if (isSelected) FontWeight.ExtraBold else FontWeight.SemiBold),
                    color = if (isSelected) Theme.textPrimary else Theme.mutedText, maxLines = 1,
                )
            }
        }
    }
}

/** YouTube, Threads, Instagram, Facebook, in the header pills' look (`SocialLinksRow`). */
@Composable
private fun SocialLinks(open: (label: String, url: String) -> Unit) {
    val links = listOf(
        "YouTube" to "https://www.youtube.com/@slowdownradijo",
        "Threads" to "https://www.threads.com/@slowdownradijocz",
        "Instagram" to "https://www.instagram.com/slowdownradijocz",
        "Facebook" to "https://www.facebook.com/slowdownradijo/",
    )
    Row(horizontalArrangement = Arrangement.spacedBy(Theme.Spacing.sm)) {
        for ((label, url) in links) {
            Box(
                Modifier
                    .size(44.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(Theme.hairline(0.08f))
                    .clickable(role = Role.Button) { open(label, url) }
                    .semantics { contentDescription = label },
                contentAlignment = Alignment.Center,
            ) {
                SocialGlyph(label)
            }
        }
    }
}

@Composable
private fun SocialGlyph(label: String) {
    when (label) {
        "Threads" -> Text("@", style = Theme.Typography.manrope(19f, FontWeight.Bold), color = Theme.textPrimary)
        "Facebook" -> Text("f", style = Theme.Typography.manrope(20f, FontWeight.ExtraBold), color = Theme.textPrimary)
        "YouTube" -> Canvas(Modifier.size(23.dp, 16.dp)) {
            val stroke = 1.5.dp.toPx()
            drawRoundRect(Theme.textPrimary, Offset(stroke / 2, stroke / 2), Size(size.width - stroke, size.height - stroke), CornerRadius(6.dp.toPx()), style = Stroke(stroke))
            val cx = size.width / 2 + 1.dp.toPx()
            val cy = size.height / 2
            val path = Path().apply {
                moveTo(cx - 3.5.dp.toPx(), cy - 4.5.dp.toPx()); lineTo(cx + 4.dp.toPx(), cy); lineTo(cx - 3.5.dp.toPx(), cy + 4.5.dp.toPx()); close()
            }
            drawPath(path, Theme.textPrimary)
        }
        else -> Canvas(Modifier.size(21.dp)) {
            val stroke = 1.5.dp.toPx()
            drawRoundRect(Theme.textPrimary, Offset(stroke / 2, stroke / 2), Size(size.width - stroke, size.height - stroke), CornerRadius(7.dp.toPx()), style = Stroke(stroke))
            drawCircle(Theme.textPrimary, radius = 4.5.dp.toPx(), style = Stroke(stroke))
            drawCircle(Theme.textPrimary, radius = 1.2.dp.toPx(), center = Offset(size.width - 5.dp.toPx(), 5.dp.toPx()))
        }
    }
}
