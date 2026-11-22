package cz.slowdownradijo.app.contests

import android.content.Intent
import android.net.Uri
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.ErrorOutline
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import cz.slowdownradijo.app.R
import cz.slowdownradijo.app.account.AccountService
import cz.slowdownradijo.app.app
import cz.slowdownradijo.app.l10n.AppLanguage
import cz.slowdownradijo.app.l10n.LocalAppLanguage
import cz.slowdownradijo.app.profile.RegisterSheet
import cz.slowdownradijo.app.profile.signInActions
import cz.slowdownradijo.app.ui.components.ListDivider
import cz.slowdownradijo.app.ui.components.PrimaryActionButton
import cz.slowdownradijo.app.ui.theme.Theme
import kotlinx.coroutines.launch
import java.time.Instant

private val letterStyle = Theme.Typography.manrope(11f, FontWeight.ExtraBold).copy(letterSpacing = 0.8.sp)
private val selectedFill = Color(0xFF2C1A3A)

/** The gift with sparkles and a soft glow (Figma "Soutěž/Ilustrace"), as `ContestIllustration`. */
@Composable
fun ContestIllustration(onYellow: Boolean = false, size: Dp = 96.dp, modifier: Modifier = Modifier) {
    Box(modifier.size(size), contentAlignment = Alignment.Center) {
        Box(
            Modifier
                .size(size * 0.92f)
                .offset(y = size * 0.04f)
                .background(
                    Brush.radialGradient(
                        listOf(if (onYellow) Color.White.copy(alpha = 0.75f) else Color(0xFF6A5BC2).copy(alpha = 0.6f), Color.Transparent),
                    ),
                    CircleShape,
                ),
        )
        Image(
            painterResource(R.drawable.contest_sparkles), contentDescription = null,
            colorFilter = ColorFilter.tint(if (onYellow) Theme.brandPurple else Color(0xFFCFC6FF)),
            modifier = Modifier.size(size),
        )
        Image(painterResource(R.drawable.contest_gift), contentDescription = null, modifier = Modifier.size(size))
    }
}

@Composable
private fun english() = LocalAppLanguage.current == AppLanguage.EN

/** The yellow card between the player and the chat (Figma H1). */
@Composable
fun ContestInfobox(contest: ContestService.Contest, onOpen: () -> Unit, onClose: () -> Unit, modifier: Modifier = Modifier) {
    val until = stringResource(R.string.contestUntil, ContestFormat.dayAndTime(contest.endsAt, english()))
    val badge = stringResource(R.string.contestBadge)
    Box(modifier.fillMaxWidth()) {
        Row(
            Modifier
                .fillMaxWidth()
                .background(Theme.sunYellow, RoundedCornerShape(Theme.Radius.card))
                .clickable(role = Role.Button, onClickLabel = stringResource(R.string.contestJoin), onClick = onOpen)
                .semantics(mergeDescendants = true) { contentDescription = "$badge, ${contest.title}, $until" }
                .padding(start = 18.dp, end = 14.dp, top = 18.dp, bottom = 18.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Theme.Spacing.sm),
        ) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    badge, style = letterStyle, color = Theme.sunYellow,
                    modifier = Modifier.background(Theme.background, CircleShape).padding(horizontal = 8.dp, vertical = 4.dp),
                )
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(contest.title, style = Theme.Typography.manrope(18f, FontWeight.ExtraBold), color = Theme.background)
                    Text(until, style = Theme.Typography.Copy.label, color = Theme.background.copy(alpha = 0.7f))
                }
                Row(
                    Modifier.background(Theme.background, CircleShape).padding(start = 16.dp, end = 14.dp, top = 10.dp, bottom = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Text(stringResource(R.string.contestJoin), style = Theme.Typography.manrope(14f, FontWeight.ExtraBold), color = Color.White)
                    Icon(Icons.AutoMirrored.Rounded.ArrowForward, contentDescription = null, tint = Theme.sunYellow, modifier = Modifier.size(16.dp))
                }
            }
            ContestIllustration(onYellow = true)
        }
        Box(
            Modifier
                .align(Alignment.TopEnd)
                .padding(2.dp)
                .size(44.dp)
                .clickable(role = Role.Button, onClickLabel = stringResource(R.string.contestCloseLabel), onClick = onClose)
                .semantics { contentDescription = "" },
            contentAlignment = Alignment.Center,
        ) {
            Box(Modifier.size(28.dp).background(Theme.background.copy(alpha = 0.1f), CircleShape), contentAlignment = Alignment.Center) {
                Icon(Icons.Rounded.Close, contentDescription = stringResource(R.string.contestCloseLabel), tint = Theme.background, modifier = Modifier.size(16.dp))
            }
        }
    }
}

/** What the listener has filled in on the contest page. */
data class ContestForm(
    val selected: String? = null,
    val answer: String = "",
    val phone: String = "",
    val showsErrors: Boolean = false,
    val serverPhoneError: Boolean = false,
    val sending: Boolean = false,
    val sendFailed: Boolean = false,
) {
    val hasAnything: Boolean get() = selected != null || answer.isNotBlank() || phone.isNotBlank()
    fun answerFor(contest: ContestService.Contest) = if (contest.isChoice) selected.orEmpty() else answer.trim()
    fun answerError(contest: ContestService.Contest) = showsErrors && answerFor(contest).isEmpty()
    val phoneError: Boolean get() = showsErrors && (serverPhoneError || ContestService.normalizedPhone(phone) == null)
}

/** Which of D1–D9 the page shows. */
sealed interface ContestPageState {
    data object Gate : ContestPageState
    data object Form : ContestPageState
    data class Sent(val entry: ContestService.Entry) : ContestPageState
    data class Entered(val entry: ContestService.Entry) : ContestPageState
    data object Ended : ContestPageState
}

class ContestPageActions(
    val onClose: () -> Unit = {},
    val onSignIn: () -> Unit = {},
    val onRules: () -> Unit = {},
    val onForm: (ContestForm) -> Unit = {},
    val onSubmit: () -> Unit = {},
)

/** The contest's own page (Figma D1–D9), drawn from its state. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ContestContent(
    contest: ContestService.Contest,
    page: ContestPageState,
    form: ContestForm,
    actions: ContestPageActions,
    modifier: Modifier = Modifier,
) {
    val en = english()
    Column(
        modifier
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp)
            .padding(top = 8.dp, bottom = 36.dp),
        verticalArrangement = Arrangement.spacedBy(Theme.Spacing.lg),
    ) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
            cz.slowdownradijo.app.ui.components.HeaderIconButton(Icons.Rounded.Close, stringResource(R.string.close), actions.onClose)
        }
        when (page) {
            is ContestPageState.Sent -> Result(contest, stringResource(R.string.contestSentTitle),
                stringResource(R.string.contestSentBody, ContestFormat.dayAndTime(contest.endsAt, en)), page.entry, sent = true, dim = false, actions.onClose)
            is ContestPageState.Entered -> Result(contest, stringResource(R.string.contestEnteredTitle),
                stringResource(R.string.contestEnteredBody), page.entry, sent = false, dim = false, actions.onClose)
            ContestPageState.Ended -> Result(contest, stringResource(R.string.contestEndedTitle),
                stringResource(R.string.contestEndedBody), null, sent = false, dim = true, actions.onClose)
            ContestPageState.Gate, ContestPageState.Form -> {
                Details(contest, actions.onRules)
                if (page == ContestPageState.Gate) Gate(actions.onSignIn) else Form(contest, form, actions)
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun Details(contest: ContestService.Contest, onRules: () -> Unit) {
    val en = english()
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(
                stringResource(R.string.contestBadge), style = letterStyle, color = Theme.background,
                modifier = Modifier.background(Theme.sunYellow, CircleShape).padding(horizontal = 8.dp, vertical = 4.dp),
            )
            Text(contest.title, style = Theme.Typography.Heading.page, color = Theme.textPrimary)
        }
        ContestIllustration()
    }
    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Fact(stringResource(R.string.contestFactUntil), ContestFormat.dayAndTime(contest.endsAt, en))
        if (contest.prize.isNotEmpty()) Fact(stringResource(R.string.contestFactPrize), contest.prize)
    }
    Text(contest.body, style = Theme.Typography.manrope(15f, FontWeight.SemiBold).copy(lineHeight = 22.sp), color = Theme.mutedText)
    if (contest.rulesUrl != null) {
        Row(
            Modifier.clickable(role = Role.Button, onClick = onRules).padding(vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text(stringResource(R.string.contestRules), style = Theme.Typography.Copy.link, color = Theme.textPrimary)
            Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, contentDescription = null, tint = Theme.mutedText, modifier = Modifier.size(18.dp))
        }
    }
    ListDivider()
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(stringResource(R.string.contestQuestion), style = Theme.Typography.manrope(12f, FontWeight.ExtraBold).copy(letterSpacing = 0.8.sp), color = Theme.gold)
        Text(contest.question, style = Theme.Typography.Heading.section, color = Theme.textPrimary)
    }
}

@Composable
private fun Fact(key: String, value: String) {
    Row(
        Modifier
            .background(Theme.statsCard, CircleShape)
            .border(1.dp, Theme.divider, CircleShape)
            .padding(horizontal = 12.dp, vertical = 8.dp)
            .semantics(mergeDescendants = true) {},
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(key, style = Theme.Typography.Copy.label, color = Theme.subtleText)
        Text(value, style = Theme.Typography.manrope(13f, FontWeight.Bold), color = Theme.textPrimary)
    }
}

@Composable
private fun Gate(onSignIn: () -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .background(Theme.statsCard, RoundedCornerShape(Theme.Radius.card))
            .border(1.dp, Theme.sunYellow.copy(alpha = 0.5f), RoundedCornerShape(Theme.Radius.card))
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(stringResource(R.string.contestGateTitle), style = Theme.Typography.Heading.item, color = Theme.textPrimary)
        Text(stringResource(R.string.contestGateBody), style = Theme.Typography.Copy.body, color = Theme.mutedText)
        Spacer(Modifier.height(4.dp))
        PrimaryActionButton(stringResource(R.string.contestGateButton), onClick = onSignIn)
    }
}

@Composable
private fun Form(contest: ContestService.Contest, form: ContestForm, actions: ContestPageActions) {
    val focus = LocalFocusManager.current
    Column(Modifier.alpha(if (form.sending) 0.5f else 1f), verticalArrangement = Arrangement.spacedBy(Theme.Spacing.lg)) {
        if (contest.isChoice) {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                contest.options.take(3).forEachIndexed { index, option ->
                    val letter = ContestService.LETTERS[index]
                    OptionRow(letter, option, selected = form.selected == letter, error = form.answerError(contest), enabled = !form.sending) {
                        actions.onForm(form.copy(selected = letter))
                    }
                }
                if (form.answerError(contest)) Text(stringResource(R.string.contestErrorPickOption), style = Theme.Typography.Copy.label, color = Theme.liveRed)
            }
        } else {
            ContestTextField(
                stringResource(R.string.contestAnswerLabel), stringResource(R.string.contestAnswerPlaceholder), form.answer,
                onChange = { actions.onForm(form.copy(answer = it)) },
                error = if (form.answerError(contest)) stringResource(R.string.contestErrorAnswer) else null,
                enabled = !form.sending, imeAction = ImeAction.Next,
            )
        }
        ContestTextField(
            stringResource(R.string.contestPhoneLabel), "+420 777 123 456", form.phone,
            onChange = { actions.onForm(form.copy(phone = it, serverPhoneError = false, showsErrors = false)) },
            hint = stringResource(R.string.contestPhoneHint),
            error = if (form.phoneError) stringResource(R.string.contestErrorPhone) else null,
            keyboardType = KeyboardType.Phone, enabled = !form.sending, imeAction = ImeAction.Done,
            onDone = { focus.clearFocus() },
        )
        Text(stringResource(R.string.contestConsent), style = Theme.Typography.manrope(12f, FontWeight.SemiBold), color = Theme.subtleText)
    }
    AnimatedVisibility(form.sendFailed) {
        Row(
            Modifier
                .fillMaxWidth()
                .background(Theme.liveRed.copy(alpha = 0.14f), RoundedCornerShape(14.dp))
                .border(1.dp, Theme.liveRed.copy(alpha = 0.6f), RoundedCornerShape(14.dp))
                .padding(14.dp)
                .semantics(mergeDescendants = true) {},
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Icon(Icons.Rounded.ErrorOutline, contentDescription = null, tint = Theme.liveRed, modifier = Modifier.size(20.dp))
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(stringResource(R.string.contestSendFailedTitle), style = Theme.Typography.manrope(14f, FontWeight.Bold), color = Theme.textPrimary)
                Text(stringResource(R.string.contestSendFailedBody), style = Theme.Typography.Copy.label, color = Theme.mutedText)
            }
        }
    }
    val enabled = form.hasAnything && !form.sending
    Row(
        Modifier
            .fillMaxWidth()
            .height(52.dp)
            .background(Theme.liveRed.copy(alpha = if (form.hasAnything) 1f else 0.35f), RoundedCornerShape(Theme.Radius.button))
            .clickable(enabled = enabled, role = Role.Button, onClick = actions.onSubmit),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (form.sending) {
            CircularProgressIndicator(color = Color.White, strokeWidth = 2.5.dp, modifier = Modifier.size(20.dp))
            Spacer(Modifier.width(10.dp))
        }
        Text(
            stringResource(
                when {
                    form.sending -> R.string.contestSending
                    form.sendFailed -> R.string.contestRetry
                    else -> R.string.contestSubmit
                },
            ),
            style = Theme.Typography.Copy.button,
            color = Color.White.copy(alpha = if (form.hasAnything) 1f else 0.6f),
        )
    }
}

@Composable
private fun OptionRow(letter: String, text: String, selected: Boolean, error: Boolean, enabled: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(14.dp)
    Row(
        Modifier
            .fillMaxWidth()
            .background(if (selected) selectedFill else Theme.statsCardRaised, shape)
            .border(if (selected) 2.dp else 1.dp, if (selected || error) Theme.liveRed else Theme.divider, shape)
            .clickable(enabled = enabled, role = Role.RadioButton, onClick = onClick)
            .semantics { this.selected = selected }
            .padding(start = 14.dp, end = 16.dp, top = 14.dp, bottom = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(Modifier.size(30.dp).background(if (selected) Theme.liveRed else Theme.divider, CircleShape), contentAlignment = Alignment.Center) {
            Text(letter, style = Theme.Typography.manrope(14f, FontWeight.ExtraBold), color = Color.White)
        }
        Text(text, style = Theme.Typography.manrope(16f, FontWeight.SemiBold), color = Theme.textPrimary, modifier = Modifier.weight(1f))
    }
}

@Composable
private fun Result(
    contest: ContestService.Contest,
    title: String,
    body: String,
    entry: ContestService.Entry?,
    sent: Boolean,
    dim: Boolean,
    onBack: () -> Unit,
) {
    val en = english()
    Column(
        Modifier.fillMaxWidth().padding(top = Theme.Spacing.lg).semantics(mergeDescendants = true) {},
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        ContestIllustration(size = 150.dp, modifier = Modifier.alpha(if (dim) 0.45f else 1f))
        Text(title, style = Theme.Typography.manrope(26f, FontWeight.ExtraBold), color = Theme.textPrimary, textAlign = TextAlign.Center)
        Text(body, style = Theme.Typography.manrope(15f, FontWeight.SemiBold), color = Theme.mutedText, textAlign = TextAlign.Center)
    }
    if (entry != null) {
        Column(
            Modifier.fillMaxWidth().background(Theme.statsCard, RoundedCornerShape(Theme.Radius.card)).padding(horizontal = 18.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(contest.title, style = Theme.Typography.manrope(15f, FontWeight.ExtraBold), color = Theme.textPrimary)
            SummaryRow(stringResource(R.string.contestSummaryAnswer), contest.answerLabel(entry.answer))
            if (sent && entry.phone != null) SummaryRow(stringResource(R.string.contestSummaryPhone), ContestFormat.phone(entry.phone))
            if (!sent) entry.createdAt?.let { SummaryRow(stringResource(R.string.contestSummarySent), ContestFormat.dayTimeShort(it, en)) }
            SummaryRow(stringResource(R.string.contestSummaryDraw), stringResource(R.string.contestDrawAfter, ContestFormat.day(contest.endsAt, en)))
        }
    }
    PrimaryActionButton(stringResource(R.string.contestBackToRadio), modifier = Modifier.padding(top = Theme.Spacing.sm), onClick = onBack)
}

@Composable
private fun SummaryRow(key: String, value: String) {
    Row(Modifier.fillMaxWidth().semantics(mergeDescendants = true) {}, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(key, style = Theme.Typography.Copy.body, color = Theme.subtleText)
        Text(value, style = Theme.Typography.manrope(14f, FontWeight.Bold), color = Theme.textPrimary, textAlign = TextAlign.End, modifier = Modifier.weight(1f))
    }
}

/** A labelled field on the contest screens and the admin form (Figma "Formulář/Pole"). */
@Composable
fun ContestTextField(
    label: String,
    placeholder: String,
    value: String,
    onChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    hint: String? = null,
    error: String? = null,
    keyboardType: KeyboardType = KeyboardType.Text,
    enabled: Boolean = true,
    multiline: Boolean = false,
    imeAction: ImeAction = ImeAction.Default,
    onDone: () -> Unit = {},
) {
    val shape = RoundedCornerShape(14.dp)
    Column(modifier, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(label, style = Theme.Typography.manrope(14f, FontWeight.Bold), color = Theme.textPrimary)
        BasicTextField(
            value = value,
            onValueChange = onChange,
            enabled = enabled,
            singleLine = !multiline,
            minLines = if (multiline) 4 else 1,
            textStyle = Theme.Typography.manrope(16f, FontWeight.SemiBold).copy(color = Theme.textPrimary),
            cursorBrush = androidx.compose.ui.graphics.SolidColor(Theme.liveRed),
            keyboardOptions = KeyboardOptions(keyboardType = keyboardType, imeAction = imeAction),
            keyboardActions = androidx.compose.foundation.text.KeyboardActions(onDone = { onDone() }),
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 52.dp)
                .background(Theme.statsCardRaised, shape)
                .border(if (error != null) 2.dp else 1.dp, if (error != null) Theme.liveRed else Theme.divider, shape)
                .semantics { contentDescription = label },
            decorationBox = { inner ->
                Box(Modifier.padding(horizontal = 16.dp, vertical = 14.dp), contentAlignment = if (multiline) Alignment.TopStart else Alignment.CenterStart) {
                    if (value.isEmpty()) Text(placeholder, style = Theme.Typography.manrope(16f, FontWeight.SemiBold), color = Theme.subtleText)
                    inner()
                }
            },
        )
        val line = error ?: hint
        if (line != null) Text(line, style = Theme.Typography.Copy.label, color = if (error != null) Theme.liveRed else Theme.subtleText)
    }
}

/** The contest page as a sheet over the home screen, with its state and the sign-in. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ContestSheet(snapshot: ContestService.Contest, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val app = context.app
    val service = app.contests
    val current by service.current.collectAsStateWithLifecycle()
    val accountState by app.account.state.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()
    val contest = current?.takeIf { it.id == snapshot.id } ?: snapshot
    var form by remember { mutableStateOf(ContestForm()) }
    var justSent by remember { mutableStateOf<ContestService.Entry?>(null) }
    var closedByServer by remember { mutableStateOf(false) }
    var registering by remember { mutableStateOf(false) }
    var registerEmail by remember { mutableStateOf(false) }
    var busy by remember { mutableStateOf(false) }
    val signedIn = accountState is AccountService.State.SignedIn

    LaunchedEffect(Unit) { service.refresh() }
    LaunchedEffect(signedIn) {
        if (signedIn) registering = false
        service.refresh()
    }

    val page = when {
        justSent != null -> ContestPageState.Sent(justSent!!)
        contest.entered && contest.myEntry != null -> ContestPageState.Entered(contest.myEntry)
        closedByServer || !contest.isRunning(Instant.now()) -> ContestPageState.Ended
        signedIn -> ContestPageState.Form
        else -> ContestPageState.Gate
    }

    fun submit() {
        val answer = form.answerFor(contest)
        if (answer.isEmpty() || ContestService.normalizedPhone(form.phone) == null) {
            form = form.copy(showsErrors = true)
            return
        }
        form = form.copy(sending = true)
        scope.launch {
            try {
                justSent = service.enter(contest, answer, form.phone)
                form = form.copy(sending = false, sendFailed = false)
            } catch (e: ContestService.ContestException) {
                form = form.copy(sending = false)
                when (e.failure) {
                    ContestService.Failure.CLOSED -> closedByServer = true
                    ContestService.Failure.ALREADY_ENTERED -> Unit // `current` now says entered → D9
                    ContestService.Failure.PHONE_INVALID -> form = form.copy(serverPhoneError = true, showsErrors = true)
                    ContestService.Failure.ANSWER_INVALID -> form = form.copy(showsErrors = true)
                    ContestService.Failure.ACCOUNT_REQUIRED -> registering = true
                    else -> form = form.copy(sendFailed = true)
                }
            }
        }
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = Theme.background,
        shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
    ) {
        ContestContent(
            contest, page, form,
            ContestPageActions(
                onClose = onDismiss,
                onSignIn = {
                    app.account.registrationSource = "contest"
                    app.analytics.track(cz.slowdownradijo.app.analytics.AnalyticsEvent.RegistrationPromptShown("contest"))
                    registerEmail = false
                    registering = true
                },
                onRules = {
                    contest.rulesUrl?.let { runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(it))) } }
                },
                onForm = { form = it },
                onSubmit = ::submit,
            ),
            modifier = Modifier.fillMaxHeight(0.94f).imePadding(),
        )
    }

    if (registering) {
        val actions = signInActions(context, scope, app.account, setBusy = { busy = it }, onEmail = { registerEmail = true })
        RegisterSheet(
            "contest", app.account.me?.nickname.orEmpty(), busy, registerEmail, actions,
            onBackFromEmail = { registerEmail = false }, onDismiss = { registering = false },
        )
    }
}
