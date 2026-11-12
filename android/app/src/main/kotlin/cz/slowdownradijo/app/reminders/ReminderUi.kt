package cz.slowdownradijo.app.reminders

import android.Manifest
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Notifications
import androidx.compose.material.icons.rounded.NotificationsOff
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import cz.slowdownradijo.app.R
import cz.slowdownradijo.app.app
import cz.slowdownradijo.app.data.Show
import cz.slowdownradijo.app.l10n.L10nLogic
import cz.slowdownradijo.app.l10n.LocalAppLanguage
import cz.slowdownradijo.app.ui.components.ToastCenter

/** The notification settings of the app, for "Nastavení" in the blocked toast. */
fun openNotificationSettings(context: Context) {
    context.startActivity(
        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    )
}

fun notificationsBlockedToast(context: Context) = ToastCenter.Toast(
    icon = Icons.Rounded.NotificationsOff,
    message = context.getString(R.string.notificationsBlockedToast),
    actionTitle = context.getString(R.string.openSettingsAction),
    action = { openNotificationSettings(context) },
)

/**
 * Turns a show's reminder on or off, asking for notifications the first
 * time (Android 13+), with the same toasts as the iOS bell.
 */
@Composable
fun rememberReminderToggle(): (show: Show, follow: Boolean) -> Unit {
    val context = LocalContext.current
    val english = LocalAppLanguage.current.isEnglish
    val reminders = context.app.reminders
    val pending = remember { arrayOfNulls<Show>(1) }

    fun enable(show: Show) {
        reminders.setFollowing(show, true)
        ToastCenter.show(
            ToastCenter.Toast(
                Icons.Rounded.Notifications,
                L10nLogic.reminderOnToast(english, show.displayTitle, reminders.nextAiringLabel(show, english)),
            )
        )
    }

    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        val show = pending[0] ?: return@rememberLauncherForActivityResult
        pending[0] = null
        if (granted && reminders.notificationsAllowed()) enable(show) else ToastCenter.show(notificationsBlockedToast(context))
    }

    return { show, follow ->
        when {
            !follow -> {
                reminders.setFollowing(show, false)
                ToastCenter.show(ToastCenter.Toast(Icons.Rounded.NotificationsOff, context.getString(R.string.reminderOffToast, show.displayTitle)))
            }
            reminders.notificationsAllowed() -> enable(show)
            Build.VERSION.SDK_INT >= 33 -> {
                pending[0] = show
                launcher.launch(Manifest.permission.POST_NOTIFICATIONS)
            }
            else -> ToastCenter.show(notificationsBlockedToast(context))
        }
    }
}
