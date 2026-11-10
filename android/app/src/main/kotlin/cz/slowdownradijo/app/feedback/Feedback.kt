package cz.slowdownradijo.app.feedback

import android.os.Build
import androidx.compose.animation.core.Animatable
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.Send
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import cz.slowdownradijo.app.BuildConfig
import cz.slowdownradijo.app.R
import cz.slowdownradijo.app.ui.components.BackHeader
import cz.slowdownradijo.app.ui.components.PrimaryActionButton
import cz.slowdownradijo.app.ui.components.SecondaryActionButton
import cz.slowdownradijo.app.ui.theme.Theme
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException

/** The phone, for the feedback email (`DeviceInfo.swift`). */
@Serializable
data class DeviceInfo(
    val appVersion: String,
    val buildNumber: String,
    val osVersion: String,
    val deviceModel: String,
    val appLanguage: String,
) {
    companion object {
        fun current(languageCode: String) = DeviceInfo(
            appVersion = BuildConfig.VERSION_NAME,
            buildNumber = BuildConfig.VERSION_CODE.toString(),
            osVersion = "Android ${Build.VERSION.RELEASE}",
            deviceModel = "${Build.MANUFACTURER} ${Build.MODEL}",
            appLanguage = languageCode.uppercase(),
        )
    }
}

/** Sends the message to `send-feedback`, which emails it to the station. */
class FeedbackService(private val client: OkHttpClient, private val endpoint: String = ENDPOINT) {
    @Serializable
    private data class Payload(val message: String, val device: DeviceInfo)

    suspend fun send(message: String, device: DeviceInfo) = withContext(Dispatchers.IO) {
        val body = Json.encodeToString(Payload.serializer(), Payload(message, device)).toRequestBody("application/json".toMediaType())
        client.newCall(Request.Builder().url(endpoint).post(body).build()).execute().use {
            if (!it.isSuccessful) throw IOException("send-feedback: ${it.code}")
        }
    }

    companion object {
        const val ENDPOINT = "https://toqoqrshyutyezoyxvlj.supabase.co/functions/v1/send-feedback"
    }
}

/** The form's state (`FeedbackViewModel.swift`). */
class FeedbackForm(private val service: FeedbackService, private val onSent: (Boolean) -> Unit = {}) {
    enum class State { IDLE, SENDING, SENT, FAILED }

    private val _message = MutableStateFlow("")
    val message: StateFlow<String> = _message.asStateFlow()
    private val _state = MutableStateFlow(State.IDLE)
    val state: StateFlow<State> = _state.asStateFlow()

    fun edit(text: String) { _message.value = text }

    val canSubmit get() = _message.value.trim().length >= 3 && _state.value != State.SENDING

    suspend fun submit(device: DeviceInfo) {
        if (!canSubmit) return
        _state.value = State.SENDING
        try {
            service.send(_message.value.trim(), device)
            _message.value = ""
            _state.value = State.SENT
            onSent(true)
        } catch (_: Exception) {
            _state.value = State.FAILED
            onSent(false)
        }
    }

    fun reset() { _state.value = State.IDLE }
}

private val successGreen = Color(0xFF28C840)

/** Zpětná vazba (`FeedbackView.swift`). */
@Composable
fun FeedbackScreen(message: String, state: FeedbackForm.State, onEdit: (String) -> Unit, onSubmit: () -> Unit, onReset: () -> Unit, back: () -> Unit) {
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(top = 20.dp, bottom = Theme.Spacing.xl),
        verticalArrangement = Arrangement.spacedBy(Theme.Spacing.lg),
    ) {
        BackHeader(stringResource(R.string.settingsFeedbackTitle), stringResource(R.string.close), back)
        Text(stringResource(R.string.settingsFeedbackIntro), style = Theme.Typography.Copy.body, color = Theme.mutedText)
        if (state == FeedbackForm.State.SENT) {
            Box(Modifier.size(64.dp).background(successGreen.copy(alpha = 0.15f), CircleShape), contentAlignment = Alignment.Center) {
                Icon(Icons.Rounded.Check, null, tint = successGreen, modifier = Modifier.size(34.dp))
            }
            Row(
                Modifier.background(successGreen.copy(alpha = 0.15f), RoundedCornerShape(8.dp)).padding(horizontal = 12.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Box(Modifier.size(10.dp).background(successGreen, CircleShape))
                Text(stringResource(R.string.sentBadge), style = Theme.Typography.manrope(14f, FontWeight.ExtraBold), color = successGreen)
            }
            Text(stringResource(R.string.settingsFeedbackSent), style = Theme.Typography.Copy.link, color = Theme.textPrimary)
            SecondaryActionButton(stringResource(R.string.settingsFeedbackSendAnother), onClick = onReset)
        } else {
            // A shake when sending fails (library P12).
            val shake = remember { Animatable(0f) }
            LaunchedEffect(state) {
                if (state == FeedbackForm.State.FAILED) for (x in listOf(10f, -10f, 6f, -6f, 0f)) shake.animateTo(x)
            }
            Column(Modifier.offset(x = shake.value.dp), verticalArrangement = Arrangement.spacedBy(Theme.Spacing.lg)) {
                Column(verticalArrangement = Arrangement.spacedBy(Theme.Spacing.md)) {
                    Box(Modifier.fillMaxWidth().heightIn(min = 160.dp).background(Theme.hairline(0.08f), RoundedCornerShape(10.dp)).padding(horizontal = 13.dp, vertical = 16.dp)) {
                        if (message.isEmpty()) Text(stringResource(R.string.settingsFeedbackPlaceholder), style = Theme.Typography.Copy.reading, color = Theme.subtleText)
                        BasicTextField(
                            message, onEdit,
                            enabled = state != FeedbackForm.State.SENDING,
                            textStyle = Theme.Typography.Copy.reading.copy(color = Theme.textPrimary),
                            cursorBrush = SolidColor(Theme.liveRed),
                            modifier = Modifier.fillMaxWidth().heightIn(min = 128.dp),
                        )
                    }
                    PrimaryActionButton(
                        stringResource(if (state == FeedbackForm.State.SENDING) R.string.settingsFeedbackSending else R.string.settingsFeedbackSend),
                        enabled = message.trim().length >= 3 && state != FeedbackForm.State.SENDING,
                        icon = Icons.AutoMirrored.Rounded.Send, onClick = onSubmit,
                    )
                }
                if (state == FeedbackForm.State.FAILED) {
                    Text(stringResource(R.string.settingsFeedbackFailed), style = Theme.Typography.manrope(14f, FontWeight.SemiBold), color = Theme.statusError)
                }
            }
        }
    }
}
