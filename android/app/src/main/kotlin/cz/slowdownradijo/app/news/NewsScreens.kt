package cz.slowdownradijo.app.news

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Notifications
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import cz.slowdownradijo.app.R
import cz.slowdownradijo.app.data.ScheduleStore
import cz.slowdownradijo.app.l10n.L10nLogic
import cz.slowdownradijo.app.l10n.LocalAppLanguage
import cz.slowdownradijo.app.ui.components.AppSwitch
import cz.slowdownradijo.app.ui.components.BackHeader
import cz.slowdownradijo.app.ui.components.ListDivider
import cz.slowdownradijo.app.ui.components.ListRow
import cz.slowdownradijo.app.ui.components.ListRowIcon
import cz.slowdownradijo.app.ui.components.PrimaryActionButton
import cz.slowdownradijo.app.ui.theme.Theme

private fun NewsPost.dateLabel(english: Boolean) = L10nLogic.formattedDate(english, dateGmt.atZone(ScheduleStore.STATION_ZONE).toLocalDate())

/** Novinky (`NewsListView.swift`): the new-post notification switch, then the posts. */
@Composable
fun NewsListScreen(state: NewsStore.State, notificationsOn: Boolean, onNotifications: (Boolean) -> Unit, onOpen: (NewsPost) -> Unit, back: () -> Unit) {
    val english = LocalAppLanguage.current.isEnglish
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(top = 20.dp, bottom = Theme.Spacing.xl),
        verticalArrangement = Arrangement.spacedBy(Theme.Spacing.lg),
    ) {
        BackHeader(stringResource(R.string.newsTitle), stringResource(R.string.close), back)
        Column {
            ListDivider()
            ListRow(
                stringResource(R.string.notificationsNewPostTitle), stringResource(R.string.notificationsNewPostDescription),
                leading = { ListRowIcon(Icons.Rounded.Notifications) },
            ) { AppSwitch(notificationsOn, onNotifications, stringResource(R.string.notificationsNewPostTitle)) }
            ListDivider()
            when (state) {
                NewsStore.State.Loading -> Box(Modifier.fillMaxWidth().padding(vertical = Theme.Spacing.xxl), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = Theme.mutedText)
                }
                NewsStore.State.Failed -> Status(stringResource(R.string.newsLoadFailed))
                is NewsStore.State.Loaded -> if (state.posts.isEmpty()) Status(stringResource(R.string.newsEmpty)) else {
                    state.posts.forEachIndexed { index, post ->
                        if (index > 0) ListDivider()
                        Row(
                            Modifier.fillMaxWidth().clickable { onOpen(post) }.padding(vertical = 20.dp),
                            horizontalArrangement = Arrangement.spacedBy(Theme.Spacing.md),
                        ) {
                            RemoteImage(post.imageUrl, Modifier.size(72.dp))
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                Text(post.title, style = Theme.Typography.Heading.item, color = Theme.textPrimary, maxLines = 3, overflow = TextOverflow.Ellipsis)
                                Text(post.dateLabel(english), style = Theme.Typography.manrope(14f, FontWeight.Normal), color = Theme.subtleText)
                            }
                        }
                    }
                }
            }
        }
    }
}

/** A post (`NewsDetailView.swift`): photo, date, title, then its paragraphs, images and videos. */
@Composable
fun NewsDetailScreen(post: NewsPost?, back: () -> Unit) {
    val english = LocalAppLanguage.current.isEnglish
    val context = LocalContext.current
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(top = 20.dp, bottom = Theme.Spacing.xl),
        verticalArrangement = Arrangement.spacedBy(Theme.Spacing.lg),
    ) {
        BackHeader(stringResource(R.string.newsTitle), stringResource(R.string.close), back)
        if (post == null) return@Column
        post.imageUrl?.let { RemoteImage(it, Modifier.fillMaxWidth().height(200.dp)) }
        Column(verticalArrangement = Arrangement.spacedBy(Theme.Spacing.sm)) {
            Text(post.dateLabel(english), style = Theme.Typography.Copy.label, color = Theme.mutedText)
            Text(post.title, style = Theme.Typography.Heading.hero, color = Theme.textPrimary)
        }
        Column(verticalArrangement = Arrangement.spacedBy(Theme.Spacing.md)) {
            for (block in post.blocks) when (block) {
                is NewsBlock.Paragraph -> Text(block.text, style = Theme.Typography.Copy.reading, color = Theme.textPrimary)
                is NewsBlock.Image -> RemoteImage(block.url, Modifier.fillMaxWidth().height(200.dp))
                is NewsBlock.Video -> PrimaryActionButton(stringResource(R.string.newsWatchVideo), icon = Icons.Rounded.PlayArrow) {
                    runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(block.url))) }
                }
            }
        }
    }
}

@Composable
private fun Status(text: String) =
    Text(text, style = Theme.Typography.Copy.body, color = Theme.mutedText, modifier = Modifier.fillMaxWidth().padding(vertical = 20.dp))

@Composable
private fun RemoteImage(url: String?, modifier: Modifier) {
    AsyncImage(url, null, modifier.clip(RoundedCornerShape(2.dp)).background(Theme.statsCard), contentScale = ContentScale.Crop)
}

