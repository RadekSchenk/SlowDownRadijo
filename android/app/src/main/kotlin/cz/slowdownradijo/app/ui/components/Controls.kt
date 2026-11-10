package cz.slowdownradijo.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBackIos
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import cz.slowdownradijo.app.ui.theme.Theme

/** The list rows' 1-high solid divider (`ListDivider`). */
@Composable
fun ListDivider(modifier: Modifier = Modifier) {
    Box(
        modifier
            .fillMaxWidth()
            .height(1.dp)
            .background(Theme.divider)
    )
}

/** A menu or settings row: title (Heading.item), optional subtitle, leading and trailing (`ListRow`). */
@Composable
fun ListRow(
    title: String,
    subtitle: String? = null,
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    leading: (@Composable () -> Unit)? = null,
    trailing: @Composable RowScope.() -> Unit = {},
) {
    Row(
        modifier
            .fillMaxWidth()
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(vertical = 20.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Theme.Spacing.md),
    ) {
        leading?.invoke()
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(title, style = Theme.Typography.Heading.item, color = Theme.textPrimary)
            if (subtitle != null) {
                Text(subtitle, style = Theme.Typography.manrope(14f, FontWeight.Normal), color = Theme.subtleText)
            }
        }
        trailing()
    }
}

@Composable
fun ListRowChevron() {
    Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, contentDescription = null, tint = Theme.textPrimary, modifier = Modifier.size(24.dp))
}

/** The red icon tile at a menu row's start (`ListRowIcon`). */
@Composable
fun ListRowIcon(icon: ImageVector) {
    Box(
        Modifier
            .size(44.dp)
            .background(Theme.liveRed.copy(alpha = 0.15f), RoundedCornerShape(8.dp)),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = Theme.liveRed, modifier = Modifier.size(22.dp))
    }
}

@Composable
fun AppSwitch(checked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    Switch(
        checked = checked,
        onCheckedChange = onCheckedChange,
        colors = SwitchDefaults.colors(
            checkedTrackColor = Theme.liveRed,
            checkedThumbColor = Theme.textPrimary,
            uncheckedTrackColor = Theme.hairline(0.12f),
            uncheckedThumbColor = Theme.mutedText,
            uncheckedBorderColor = Theme.hairline(0f),
        ),
    )
}

/** A 34 × 34 rounded icon button in a page header (`HeaderIconButton`). */
@Composable
fun HeaderIconButton(icon: ImageVector, description: String, onClick: () -> Unit) {
    Box(
        Modifier
            .size(34.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(Theme.hairline(0.08f))
            .clickable(role = Role.Button, onClick = onClick)
            .semantics { contentDescription = description },
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = Theme.textPrimary, modifier = Modifier.size(18.dp))
    }
}

/** Back button and the page's title (`BackHeaderView`). */
@Composable
fun BackHeader(title: String, backDescription: String, onBack: () -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        HeaderIconButton(Icons.AutoMirrored.Rounded.ArrowBackIos, backDescription, onBack)
        Spacer(Modifier.width(Theme.Spacing.md))
        Text(title, style = Theme.Typography.Heading.page, color = Theme.textPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/** The full-width red button (`PrimaryActionButton`). */
@Composable
fun PrimaryActionButton(title: String, enabled: Boolean = true, modifier: Modifier = Modifier, icon: ImageVector? = null, onClick: () -> Unit) {
    Row(
        modifier
            .fillMaxWidth()
            .height(48.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(Theme.liveRed.copy(alpha = if (enabled) 1f else 0.4f))
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) {
            Icon(icon, contentDescription = null, tint = Theme.textPrimary, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(Theme.Spacing.sm))
        }
        Text(title, style = Theme.Typography.Copy.button, color = Theme.textPrimary)
    }
}

/** The quiet full-width button (`SecondaryActionButton`). */
@Composable
fun SecondaryActionButton(title: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Box(
        modifier
            .fillMaxWidth()
            .height(48.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(Theme.hairline(0.08f))
            .clickable(role = Role.Button, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(title, style = Theme.Typography.Copy.button, color = Theme.textPrimary)
    }
}
