package cz.slowdownradijo.app

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.saveable.Saver
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import cz.slowdownradijo.app.ui.components.ToastHost
import cz.slowdownradijo.app.ui.theme.Theme

/** The bottom bar's tabs, as on iOS 1.1: Rádio, Statistiky, Vzkaz. */
enum class Tab(val label: Int, val icon: Int) {
    RADIO(R.string.tabRadio, R.drawable.tab_icon_radio),
    STATS(R.string.tabStats, R.drawable.tab_icon_stats),
    MESSAGE(R.string.tabMessage, R.drawable.tab_icon_message),
}

/**
 * The app's frame (`RootTabView.swift`): the selected tab's page over the
 * bottom bar, and the menu over everything. A page is built on its first
 * visit and kept, so it keeps its scroll and state.
 */
@Composable
fun RootScreen(
    selected: Tab,
    onSelect: (Tab) -> Unit,
    menuOpen: Boolean,
    menu: @Composable () -> Unit,
    page: @Composable (Tab) -> Unit,
) {
    var visited by rememberSaveable(stateSaver = Saver<Set<Tab>, List<Int>>({ it.map(Tab::ordinal) }, { list -> list.map { Tab.entries[it] }.toSet() })) {
        mutableStateOf(setOf(selected))
    }
    if (selected !in visited) visited = visited + selected

    Box(Modifier.fillMaxSize().background(Theme.background)) {
        Column(Modifier.fillMaxSize()) {
            ToastHost(Modifier.weight(1f).fillMaxWidth()) {
                for (tab in Tab.entries) {
                    if (tab !in visited) continue
                    val isSelected = tab == selected
                    Box(
                        Modifier
                            .fillMaxSize()
                            .then(if (isSelected) Modifier else Modifier.size(0.dp))
                    ) {
                        page(tab)
                    }
                }
            }
            BottomBar(selected, onSelect)
        }
        AnimatedVisibility(
            menuOpen,
            enter = fadeIn() + slideInVertically { it / 8 },
            exit = fadeOut() + slideOutVertically { it / 8 },
        ) {
            ToastHost(Modifier.fillMaxSize()) { menu() }
        }
    }
}

/**
 * Figma `bottom-nav`: a hairline, then three equal columns of 22 icons and
 * 11 Bold labels, 10 above and 6 below, on the bar's own purple.
 */
@Composable
fun BottomBar(selected: Tab, onSelect: (Tab) -> Unit) = cz.slowdownradijo.app.ui.components.CapFontScale(cz.slowdownradijo.app.ui.components.TAB_BAR_MAX_FONT_SCALE) {
    Column(
        Modifier
            .fillMaxWidth()
            .background(Theme.tabBarBackground)
            .navigationBarsPadding()
    ) {
        Box(Modifier.fillMaxWidth().height(1.dp).background(Theme.hairline(0.08f)))
        Row(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(top = Theme.TabBar.topPadding, bottom = Theme.TabBar.iconLabelSpacing),
        ) {
            for (tab in Tab.entries) {
                val isSelected = tab == selected
                val color = if (isSelected) Theme.liveRed else Theme.tabBarUnselected
                Column(
                    Modifier
                        .weight(1f)
                        .clickable(role = Role.Tab) { onSelect(tab) }
                        .semantics { this.selected = isSelected },
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Icon(painterResource(tab.icon), contentDescription = null, tint = color, modifier = Modifier.size(Theme.TabBar.iconSize))
                    Text(
                        stringResource(tab.label),
                        style = Theme.Typography.manrope(Theme.TabBar.labelSize.value, FontWeight.Bold),
                        color = color, maxLines = 1,
                        modifier = Modifier.heightIn(min = 15.dp),
                    )
                }
            }
        }
    }
}
