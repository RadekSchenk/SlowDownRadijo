package cz.slowdownradijo.app.home

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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.BarChart
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import cz.slowdownradijo.app.R
import cz.slowdownradijo.app.ui.theme.Theme

/** A question card on the home screen with two answers (`HomePromptCard.swift`). */
@Composable
fun HomePromptCard(icon: ImageVector, title: String, message: String, decline: String, accept: String, onAnswer: (Boolean) -> Unit, modifier: Modifier = Modifier) {
    Column(
        modifier.fillMaxWidth().background(Theme.statsCardRaised, RoundedCornerShape(12.dp)).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(Theme.Spacing.md),
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Box(Modifier.size(32.dp).background(Theme.liveRed.copy(alpha = 0.15f), RoundedCornerShape(8.dp)), contentAlignment = Alignment.Center) {
                Icon(icon, null, tint = Theme.liveRed, modifier = Modifier.size(16.dp))
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(title, style = Theme.Typography.Heading.item, color = Theme.textPrimary)
                Text(message, style = Theme.Typography.Copy.body, color = Theme.mutedText)
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(Theme.Spacing.sm)) {
            Answer(decline, primary = false, Modifier.weight(1f)) { onAnswer(false) }
            Answer(accept, primary = true, Modifier.weight(1f)) { onAnswer(true) }
        }
    }
}

@Composable
private fun Answer(title: String, primary: Boolean, modifier: Modifier, onClick: () -> Unit) {
    Box(
        modifier.height(44.dp).clip(RoundedCornerShape(10.dp))
            .background(if (primary) Theme.liveRed else Theme.hairline(0.08f))
            .clickable(role = Role.Button, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { Text(title, style = Theme.Typography.Copy.button, color = Theme.textPrimary) }
}

/** "May we measure anonymously?" from the third launch (`AnalyticsConsentCard`). */
@Composable
fun AnalyticsConsentCard(onAnswer: (Boolean) -> Unit, modifier: Modifier = Modifier) = HomePromptCard(
    Icons.Rounded.BarChart,
    stringResource(R.string.analyticsConsentTitle), stringResource(R.string.analyticsConsentBody),
    stringResource(R.string.analyticsConsentDecline), stringResource(R.string.analyticsConsentAllow),
    onAnswer, modifier,
)
