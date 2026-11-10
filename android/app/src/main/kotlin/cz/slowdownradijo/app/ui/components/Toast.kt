package cz.slowdownradijo.app.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import cz.slowdownradijo.app.ui.theme.Theme
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** A short message at the bottom of the screen, with an optional action (`ToastCenter`). */
object ToastCenter {
    data class Toast(
        val icon: ImageVector,
        val message: String,
        val actionTitle: String? = null,
        val action: (() -> Unit)? = null,
        val id: Long = System.nanoTime(),
    )

    private val _current = MutableStateFlow<Toast?>(null)
    val current: StateFlow<Toast?> = _current.asStateFlow()

    fun show(toast: Toast) {
        _current.value = toast
    }

    fun dismiss() {
        _current.value = null
    }
}

/** Shows [ToastCenter]'s toast over [content], 3 s (5 s with an action). */
@Composable
fun ToastHost(modifier: Modifier = Modifier, content: @Composable BoxScope.() -> Unit) {
    val toast by ToastCenter.current.collectAsStateWithLifecycle()
    val view = LocalView.current
    LaunchedEffect(toast?.id) {
        val shown = toast ?: return@LaunchedEffect
        view.announceForAccessibility(shown.message)
        delay(if (shown.action == null) 3000 else 5000)
        if (ToastCenter.current.value?.id == shown.id) ToastCenter.dismiss()
    }
    val last = remember { arrayOfNulls<ToastCenter.Toast>(1) }
    if (toast != null) last[0] = toast
    Box(modifier) {
        content()
        AnimatedVisibility(
            visible = toast != null,
            enter = fadeIn() + slideInVertically { it / 2 },
            exit = fadeOut() + slideOutVertically { it / 2 },
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(horizontal = 20.dp, vertical = 12.dp),
        ) {
            last[0]?.let { ToastView(it) }
        }
    }
}

@Composable
private fun ToastView(toast: ToastCenter.Toast) {
    Row(
        Modifier
            .fillMaxWidth()
            .background(Theme.statsCardRaised, RoundedCornerShape(12.dp))
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(toast.icon, contentDescription = null, tint = Theme.liveRed, modifier = Modifier.size(20.dp))
        Text(toast.message, style = Theme.Typography.Copy.body, color = Theme.textPrimary, modifier = Modifier.weight(1f))
        if (toast.actionTitle != null && toast.action != null) {
            Text(
                toast.actionTitle, style = Theme.Typography.Copy.link, color = Theme.liveRed,
                modifier = Modifier.clickable {
                    toast.action.invoke()
                    ToastCenter.dismiss()
                },
            )
        }
    }
}
