package cz.slowdownradijo.app.contests

import android.app.DatePickerDialog
import android.app.TimePickerDialog
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.ErrorOutline
import androidx.compose.material.icons.rounded.RadioButtonUnchecked
import androidx.compose.material.icons.rounded.Remove
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.ClipEntry
import androidx.compose.ui.platform.LocalClipboard
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import cz.slowdownradijo.app.R
import cz.slowdownradijo.app.account.AccountError
import cz.slowdownradijo.app.app
import cz.slowdownradijo.app.l10n.AppLanguage
import cz.slowdownradijo.app.l10n.LocalAppLanguage
import cz.slowdownradijo.app.profile.ConfirmDialog
import cz.slowdownradijo.app.profile.SubPage
import cz.slowdownradijo.app.ui.components.ListDivider
import cz.slowdownradijo.app.ui.components.PrimaryActionButton
import cz.slowdownradijo.app.ui.components.SecondaryActionButton
import cz.slowdownradijo.app.ui.components.ToastCenter
import cz.slowdownradijo.app.ui.theme.Theme
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId

/** Profil ▸ Správa ▸ Soutěže pages (Figma "Soutěže" S1–S6), as `ContestAdminRoute`. */
sealed interface ContestAdminRoute {
    data object List : ContestAdminRoute
    data object New : ContestAdminRoute
    data class Detail(val id: Long) : ContestAdminRoute
}

@Composable
private fun english() = LocalAppLanguage.current == AppLanguage.EN

@Composable
private fun Chip(text: String, fill: Color, color: Color) = Text(
    text, style = Theme.Typography.manrope(11f, FontWeight.ExtraBold).copy(letterSpacing = 0.6.sp), color = color,
    modifier = Modifier.background(fill, CircleShape).padding(horizontal = 8.dp, vertical = 3.dp),
)

@Composable
private fun Stat(value: Int, label: String, modifier: Modifier) {
    Column(
        modifier.background(Theme.statsCardRaised, RoundedCornerShape(12.dp)).padding(horizontal = 12.dp, vertical = 10.dp).semantics(mergeDescendants = true) {},
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Text("$value", style = Theme.Typography.manrope(20f, FontWeight.ExtraBold), color = Theme.textPrimary)
        Text(label, style = Theme.Typography.manrope(12f, FontWeight.SemiBold), color = Theme.subtleText)
    }
}

@Composable
private fun ListEntry(title: String, subtitle: String?, subtitleColor: Color = Theme.subtleText, onClick: () -> Unit) {
    androidx.compose.foundation.layout.Row(
        Modifier.fillMaxWidth().clickable(role = Role.Button, onClick = onClick).padding(vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(title, style = Theme.Typography.manrope(16f, FontWeight.SemiBold), color = Theme.textPrimary)
            if (subtitle != null) Text(subtitle, style = Theme.Typography.Copy.label, color = subtitleColor)
        }
        Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, contentDescription = null, tint = Theme.mutedText, modifier = Modifier.size(22.dp))
    }
    ListDivider()
}

@Composable
private fun SectionTitle(text: String) = Text(text, style = Theme.Typography.Heading.section, color = Theme.textPrimary)

// MARK: - S1 / S2

@Composable
fun ContestAdminList(
    overview: ContestAdmin.Overview?,
    onOpen: (Long) -> Unit,
    onNew: () -> Unit,
    onEnd: (ContestAdmin.Summary) -> Unit,
) {
    val en = english()
    Text(stringResource(R.string.adminContestsBody), style = Theme.Typography.Copy.body, color = Theme.mutedText)
    val current = overview?.current
    when {
        overview == null -> Box(Modifier.fillMaxWidth().padding(top = Theme.Spacing.lg), contentAlignment = Alignment.Center) {
            CircularProgressIndicator(color = Color.White)
        }
        current != null -> {
            Column(
                Modifier
                    .fillMaxWidth()
                    .background(Theme.statsCard, RoundedCornerShape(Theme.Radius.card))
                    .border(1.dp, Theme.sunYellow.copy(alpha = 0.45f), RoundedCornerShape(Theme.Radius.card))
                    .padding(horizontal = 18.dp, vertical = 16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Chip(stringResource(R.string.adminContestRunningBadge), Theme.sunYellow, Theme.background)
                Text(current.title, style = Theme.Typography.manrope(17f, FontWeight.ExtraBold), color = Theme.textPrimary)
                Text(
                    stringResource(
                        R.string.adminContestRunningInfo,
                        current.startsAt?.let { ContestFormat.day(it, en) }.orEmpty(),
                        current.endsAt?.let { ContestFormat.dayAndTime(it, en) }.orEmpty(),
                    ),
                    style = Theme.Typography.Copy.label, color = Theme.mutedText,
                )
                androidx.compose.foundation.layout.Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Stat(current.entries, stringResource(R.string.adminContestEntries), Modifier.weight(1f))
                    if (current.answerType == "choice") Stat(current.correct, stringResource(R.string.adminContestCorrect), Modifier.weight(1f))
                    Stat(current.dismissed, stringResource(R.string.adminContestDismissed), Modifier.weight(1f))
                }
                ListDivider()
                androidx.compose.foundation.layout.Row(
                    Modifier.fillMaxWidth().clickable(role = Role.Button) { onOpen(current.id) },
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(stringResource(R.string.adminContestAnswersRow), style = Theme.Typography.manrope(16f, FontWeight.SemiBold), color = Theme.textPrimary, modifier = Modifier.weight(1f))
                    Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, contentDescription = null, tint = Theme.mutedText, modifier = Modifier.size(22.dp))
                }
            }
            Text(
                stringResource(R.string.adminContestEnd), style = Theme.Typography.Copy.button, color = Theme.liveRed, textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth().clickable(role = Role.Button) { onEnd(current) }.padding(vertical = 12.dp),
            )
        }
        else -> {
            Column(
                Modifier
                    .fillMaxWidth()
                    .background(Theme.statsCard, RoundedCornerShape(Theme.Radius.card))
                    .drawBehind {
                        drawRoundRect(
                            Theme.divider, cornerRadius = CornerRadius(20.dp.toPx()),
                            style = Stroke(1.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(6.dp.toPx(), 6.dp.toPx()))),
                        )
                    }
                    .padding(vertical = 20.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(stringResource(R.string.adminContestNoneTitle), style = Theme.Typography.Heading.item, color = Theme.textPrimary)
                Text(stringResource(R.string.adminContestNoneBody), style = Theme.Typography.Copy.body, color = Theme.mutedText)
            }
            PrimaryActionButton(stringResource(R.string.adminContestNew), onClick = onNew)
        }
    }
    if (!overview?.previous.isNullOrEmpty()) {
        Column(Modifier.padding(top = Theme.Spacing.sm), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            SectionTitle(stringResource(R.string.adminContestPrevious))
            overview!!.previous.forEach { s ->
                val date = s.endTime?.let { ContestFormat.day(it, en) }.orEmpty()
                val line = stringResource(if (s.endedEarly) R.string.adminContestEndedEarlyRow else R.string.adminContestEndedRow, date, s.entries)
                val waiting = s.drawnAt == null && s.entries > 0
                ListEntry(
                    s.title,
                    if (waiting) "$line · ${stringResource(R.string.adminContestAwaitingDraw).lowercase()}" else line,
                    if (waiting) Theme.gold else Theme.subtleText,
                ) { onOpen(s.id) }
            }
        }
    }
}

// MARK: - S3 / S3b

@Composable
fun ContestAdminNew(
    draft: ContestAdmin.Draft,
    showsErrors: Boolean,
    working: Boolean,
    onDraft: (ContestAdmin.Draft) -> Unit,
    onPickEnd: () -> Unit,
    onReview: () -> Unit,
) {
    val en = english()
    val problems = if (showsErrors) draft.problems() else emptySet()
    val required = stringResource(R.string.adminContestErrorRequired)
    ContestTextField(
        stringResource(R.string.adminContestFieldTitle), "", draft.title, { onDraft(draft.copy(title = it)) },
        hint = "${draft.title.length}/60 · ${stringResource(R.string.adminContestFieldTitleHint)}",
        error = required.takeIf { ContestAdmin.Draft.Field.TITLE in problems },
    )
    ContestTextField(
        stringResource(R.string.adminContestFieldBody), "", draft.body, { onDraft(draft.copy(body = it)) },
        hint = stringResource(R.string.adminContestFieldBodyHint), multiline = true,
        error = required.takeIf { ContestAdmin.Draft.Field.BODY in problems },
    )
    ContestTextField(
        stringResource(R.string.adminContestFieldQuestion), "", draft.question, { onDraft(draft.copy(question = it)) },
        error = required.takeIf { ContestAdmin.Draft.Field.QUESTION in problems },
    )
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(stringResource(R.string.adminContestAnswerType), style = Theme.Typography.manrope(14f, FontWeight.Bold), color = Theme.textPrimary)
        androidx.compose.foundation.layout.Row(
            Modifier.fillMaxWidth().background(Theme.statsCardRaised, RoundedCornerShape(14.dp)).padding(4.dp),
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            listOf(true to R.string.adminContestTypeChoice, false to R.string.adminContestTypeText).forEach { (choice, label) ->
                val on = draft.isChoice == choice
                Text(
                    stringResource(label), style = Theme.Typography.manrope(14f, FontWeight.ExtraBold), color = if (on) Color.White else Theme.mutedText,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .weight(1f)
                        .background(if (on) Theme.liveRed else Color.Transparent, RoundedCornerShape(11.dp))
                        .clickable(role = Role.Tab) { onDraft(draft.copy(isChoice = choice)) }
                        .semantics { selected = on }
                        .padding(vertical = 10.dp),
                )
            }
        }
    }
    if (draft.isChoice) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(stringResource(R.string.adminContestOptions), style = Theme.Typography.manrope(14f, FontWeight.Bold), color = Theme.textPrimary)
            draft.options.forEachIndexed { index, option ->
                val letter = ContestService.LETTERS[index]
                val correct = draft.correctOption == index
                val missing = ContestAdmin.Draft.Field.OPTIONS in problems && option.isBlank()
                val shape = RoundedCornerShape(14.dp)
                androidx.compose.foundation.layout.Row(
                    Modifier
                        .fillMaxWidth()
                        .height(52.dp)
                        .background(Theme.statsCardRaised, shape)
                        .border(1.dp, if (missing) Theme.liveRed else if (correct) Theme.spotifyGreen else Theme.divider, shape)
                        .padding(start = 14.dp, end = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Text(letter, style = Theme.Typography.manrope(14f, FontWeight.ExtraBold), color = Theme.mutedText)
                    val placeholder = stringResource(R.string.adminContestOptionPlaceholder, letter)
                    BasicTextField(
                        option, { value -> onDraft(draft.copy(options = draft.options.toMutableList().also { it[index] = value })) },
                        singleLine = true,
                        textStyle = Theme.Typography.manrope(16f, FontWeight.SemiBold).copy(color = Theme.textPrimary),
                        cursorBrush = androidx.compose.ui.graphics.SolidColor(Theme.liveRed),
                        modifier = Modifier.weight(1f).semantics { contentDescription = placeholder },
                        decorationBox = { inner ->
                            Box { if (option.isEmpty()) Text(placeholder, style = Theme.Typography.manrope(16f, FontWeight.SemiBold), color = Theme.subtleText); inner() }
                        },
                    )
                    Box(
                        Modifier.size(44.dp).clickable(role = Role.RadioButton) { onDraft(draft.copy(correctOption = index)) }.semantics { selected = correct },
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            if (correct) Icons.Rounded.CheckCircle else Icons.Rounded.RadioButtonUnchecked,
                            contentDescription = stringResource(R.string.adminContestCorrectMark),
                            tint = if (correct) Theme.spotifyGreen else Theme.statsBarMuted, modifier = Modifier.size(24.dp),
                        )
                    }
                }
            }
            val optionsError = ContestAdmin.Draft.Field.OPTIONS in problems
            Text(
                stringResource(if (optionsError) R.string.adminContestErrorOptions else R.string.adminContestOptionsHint),
                style = Theme.Typography.Copy.label, color = if (optionsError) Theme.liveRed else Theme.subtleText,
            )
        }
    } else {
        Text(stringResource(R.string.adminContestTextHint), style = Theme.Typography.Copy.label, color = Theme.subtleText)
    }
    androidx.compose.foundation.layout.Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        ContestTextField(
            stringResource(R.string.adminContestFieldPrize), "", draft.prize, { onDraft(draft.copy(prize = it)) },
            hint = stringResource(R.string.adminContestFieldPrizeHint), modifier = Modifier.weight(1f),
            error = required.takeIf { ContestAdmin.Draft.Field.PRIZE in problems },
        )
        Column(Modifier.width(140.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(stringResource(R.string.adminContestFieldWinners), style = Theme.Typography.manrope(14f, FontWeight.Bold), color = Theme.textPrimary)
            androidx.compose.foundation.layout.Row(
                Modifier.fillMaxWidth().height(52.dp).background(Theme.statsCardRaised, RoundedCornerShape(14.dp)).border(1.dp, Theme.divider, RoundedCornerShape(14.dp)),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(Modifier.size(44.dp).clickable(enabled = draft.winnersCount > 1, role = Role.Button) { onDraft(draft.copy(winnersCount = draft.winnersCount - 1)) }, contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.Remove, contentDescription = "−", tint = Theme.textPrimary)
                }
                Text("${draft.winnersCount}", style = Theme.Typography.manrope(16f, FontWeight.SemiBold), color = Theme.textPrimary, textAlign = TextAlign.Center, modifier = Modifier.weight(1f))
                Box(Modifier.size(44.dp).clickable(enabled = draft.winnersCount < 20, role = Role.Button) { onDraft(draft.copy(winnersCount = draft.winnersCount + 1)) }, contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.Add, contentDescription = "+", tint = Theme.textPrimary)
                }
            }
        }
    }
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(stringResource(R.string.adminContestFieldEnd), style = Theme.Typography.manrope(14f, FontWeight.Bold), color = Theme.textPrimary)
        val endError = ContestAdmin.Draft.Field.END in problems
        Text(
            ContestFormat.dayAndTime(draft.endsAt, en), style = Theme.Typography.manrope(16f, FontWeight.SemiBold), color = Theme.textPrimary,
            modifier = Modifier
                .fillMaxWidth()
                .background(Theme.statsCardRaised, RoundedCornerShape(14.dp))
                .border(if (endError) 2.dp else 1.dp, if (endError) Theme.liveRed else Theme.divider, RoundedCornerShape(14.dp))
                .clickable(role = Role.Button, onClick = onPickEnd)
                .padding(horizontal = 16.dp, vertical = 15.dp),
        )
        Text(
            stringResource(if (endError) R.string.adminContestErrorEnd else R.string.adminContestFieldEndHint),
            style = Theme.Typography.Copy.label, color = if (endError) Theme.liveRed else Theme.subtleText,
        )
    }
    ContestTextField(
        stringResource(R.string.adminContestFieldRules), "slowdownradijo.cz/pravidla-soutezi", draft.rulesUrl, { onDraft(draft.copy(rulesUrl = it)) },
        hint = stringResource(R.string.adminContestFieldRulesHint), keyboardType = KeyboardType.Uri,
        error = stringResource(R.string.adminContestErrorRules).takeIf { ContestAdmin.Draft.Field.RULES in problems },
    )
    PrimaryActionButton(stringResource(R.string.adminContestReview), enabled = !working, onClick = onReview)
}

/** S3c: the card as listeners will see it, then start or keep editing. */
@Composable
fun ContestLaunchConfirmation(draft: ContestAdmin.Draft, working: Boolean, onLaunch: () -> Unit, onEdit: () -> Unit) {
    Column(Modifier.padding(horizontal = 20.dp).padding(top = 8.dp, bottom = 24.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text(stringResource(R.string.adminContestLaunchTitle), style = Theme.Typography.Heading.hero, color = Theme.textPrimary)
        Text(stringResource(R.string.adminContestLaunchPreview), style = Theme.Typography.Copy.body, color = Theme.mutedText)
        ContestInfobox(draft.preview(), onOpen = {}, onClose = {})
        Text(stringResource(R.string.adminContestLaunchBody), style = Theme.Typography.Copy.body, color = Theme.mutedText)
        PrimaryActionButton(stringResource(R.string.adminContestLaunch), enabled = !working, onClick = onLaunch)
        SecondaryActionButton(stringResource(R.string.adminContestEdit), onClick = onEdit)
    }
}

// MARK: - S5 / S6

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun ContestAdminDetail(
    detail: ContestAdmin.Detail?,
    drawing: Boolean,
    onDraw: (Int?) -> Unit,
    onExport: () -> Unit,
    onPhone: (String, PhoneAction) -> Unit,
) {
    val en = english()
    if (detail == null) {
        Box(Modifier.fillMaxWidth().padding(top = Theme.Spacing.lg), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = Color.White) }
        return
    }
    val s = detail.summary
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        if (s.isRunning) Chip(stringResource(R.string.adminContestRunningBadge), Theme.sunYellow, Theme.background)
        else Chip(stringResource(R.string.adminContestEndedOn, s.endTime?.let { ContestFormat.day(it, en) }.orEmpty()), Theme.divider, Theme.mutedText)
        Text(s.title, style = Theme.Typography.Heading.page, color = Theme.textPrimary)
        Text(detail.question, style = Theme.Typography.Copy.body, color = Theme.mutedText)
    }
    androidx.compose.foundation.layout.Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Stat(s.entries, stringResource(R.string.adminContestEntries), Modifier.weight(1f))
        if (s.answerType == "choice") Stat(s.correct, stringResource(R.string.adminContestCorrect), Modifier.weight(1f))
        Stat(s.winners, stringResource(R.string.adminContestWinnersCount), Modifier.weight(1f))
    }
    if (detail.winners.isNotEmpty()) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            SectionTitle(stringResource(R.string.adminContestWinners))
            Text(stringResource(R.string.adminContestWinnersBody), style = Theme.Typography.Copy.body, color = Theme.mutedText)
            detail.winners.forEach { w ->
                Column(
                    Modifier.fillMaxWidth().background(Theme.statsCard, RoundedCornerShape(16.dp)).padding(horizontal = 16.dp, vertical = 14.dp),
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Text(w.nickname ?: "—", style = Theme.Typography.manrope(14f, FontWeight.Bold), color = Theme.mutedText)
                    val phone = w.phone
                    if (phone != null) {
                        var menu by remember { mutableStateOf(false) }
                        Box {
                            SelectionContainer {
                                Text(
                                    ContestFormat.phone(phone), style = Theme.Typography.manrope(20f, FontWeight.ExtraBold), color = Theme.textPrimary,
                                    modifier = Modifier.combinedClickable(onClick = { menu = true }, onLongClick = { menu = true }),
                                )
                            }
                            DropdownMenu(menu, onDismissRequest = { menu = false }, containerColor = Theme.statsCardRaised) {
                                listOf(
                                    PhoneAction.COPY to R.string.adminContestCopyPhone,
                                    PhoneAction.CALL to R.string.adminContestCall,
                                    PhoneAction.SMS to R.string.adminContestSMS,
                                ).forEach { (action, label) ->
                                    DropdownMenuItem(
                                        text = { Text(stringResource(label), style = Theme.Typography.Copy.body, color = Theme.textPrimary) },
                                        onClick = { menu = false; onPhone(phone, action) },
                                    )
                                }
                            }
                        }
                    } else {
                        Text(stringResource(R.string.adminContestPhoneDeleted), style = Theme.Typography.Copy.body, color = Theme.subtleText)
                    }
                    w.answer?.let { Text(detail.answerLabel(it), style = Theme.Typography.Copy.label, color = Theme.subtleText) }
                }
            }
            SecondaryActionButton(stringResource(R.string.adminContestDrawAgain)) { if (!drawing) onDraw(1) }
        }
    }
    if (s.answerType == "choice" && s.entries > 0) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            SectionTitle(stringResource(R.string.adminContestDistribution))
            detail.options.take(3).forEachIndexed { index, option ->
                val letter = ContestService.LETTERS[index]
                val count = detail.distribution[letter] ?: 0
                val share = count.toFloat() / maxOf(1, s.entries)
                val correct = detail.correctOption == index
                Column(Modifier.semantics(mergeDescendants = true) {}, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    androidx.compose.foundation.layout.Row {
                        Text(
                            "$letter · $option" + if (correct) "  ✓ ${stringResource(R.string.adminContestCorrectMark)}" else "",
                            style = Theme.Typography.manrope(14f, FontWeight.Bold), color = if (correct) Theme.spotifyGreen else Theme.textPrimary,
                            modifier = Modifier.weight(1f),
                        )
                        Text("$count · ${kotlin.math.round(share * 100).toInt()} %", style = Theme.Typography.Copy.label, color = Theme.mutedText)
                    }
                    Box(Modifier.fillMaxWidth().height(8.dp).background(Theme.statsCardRaised, CircleShape)) {
                        Box(Modifier.fillMaxWidth(share.coerceAtLeast(0.01f)).height(8.dp).background(if (correct) Theme.spotifyGreen else Theme.statsBarMuted, CircleShape))
                    }
                }
            }
        }
    }
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        SectionTitle(stringResource(R.string.adminContestAnswers))
        if (detail.entries.isEmpty()) Text(stringResource(R.string.adminContestNoAnswers), style = Theme.Typography.Copy.body, color = Theme.mutedText, modifier = Modifier.padding(vertical = 8.dp))
        detail.entries.take(200).forEach { e ->
            androidx.compose.foundation.layout.Row(
                Modifier.fillMaxWidth().padding(vertical = 12.dp).semantics(mergeDescendants = true) {},
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    Text((e.nickname ?: "—") + if (e.isCorrect == true) "  ✓" else "", style = Theme.Typography.manrope(16f, FontWeight.SemiBold), color = Theme.textPrimary)
                    SelectionContainer {
                        Text(listOfNotNull(detail.answerLabel(e.answer), e.phone?.let(ContestFormat::phone)).joinToString(" · "), style = Theme.Typography.Copy.label, color = Theme.subtleText)
                    }
                }
                Text(e.at?.let { ContestFormat.dayTimeShort(it, en) }.orEmpty(), style = Theme.Typography.Copy.label, color = Theme.mutedText)
            }
            ListDivider()
        }
    }
    Column(Modifier.padding(top = Theme.Spacing.sm), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        if (!s.isRunning && detail.winners.isEmpty() && s.entries > 0) {
            PrimaryActionButton(stringResource(R.string.adminContestDrawButton), enabled = !drawing) { onDraw(null) }
        }
        if (detail.entries.isNotEmpty()) SecondaryActionButton(stringResource(R.string.adminContestExport), onClick = onExport)
    }
}

enum class PhoneAction { COPY, CALL, SMS }

/** The pages with their state, inside the Profil tab. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ContestAdminFlow(route: ContestAdminRoute, navigate: (ContestAdminRoute?) -> Unit) {
    val context = LocalContext.current
    val app = context.app
    val admin = app.contestAdmin
    val overview by admin.overview.collectAsState()
    val scope = rememberCoroutineScope()
    val clipboard = LocalClipboard.current
    fun toast(text: String, icon: androidx.compose.ui.graphics.vector.ImageVector = Icons.Rounded.ErrorOutline) =
        ToastCenter.show(ToastCenter.Toast(icon, text))
    fun toastError(e: AccountError) = toast(context.getString(ContestAdmin.messageRes(e)))

    when (route) {
        ContestAdminRoute.List -> {
            var ending by remember { mutableStateOf<ContestAdmin.Summary?>(null) }
            LaunchedEffect(Unit) { try { admin.reload() } catch (e: AccountError) { toastError(e) } }
            SubPage(stringResource(R.string.adminContests), back = { navigate(null) }) {
                ContestAdminList(overview, onOpen = { navigate(ContestAdminRoute.Detail(it)) }, onNew = { navigate(ContestAdminRoute.New) }, onEnd = { ending = it })
            }
            ending?.let { s ->
                ConfirmDialog(
                    stringResource(R.string.adminContestEndTitle), stringResource(R.string.adminContestEndBody),
                    stringResource(R.string.adminContestEnd), destructive = true, onDismiss = { ending = null },
                ) {
                    ending = null
                    scope.launch {
                        try {
                            admin.end(s.id)
                            toast(context.getString(R.string.adminContestEndedToast), Icons.Rounded.CheckCircle)
                        } catch (e: AccountError) { toastError(e) }
                    }
                }
            }
        }
        ContestAdminRoute.New -> {
            var draft by remember { mutableStateOf(ContestAdmin.Draft()) }
            var showsErrors by remember { mutableStateOf(false) }
            var confirming by remember { mutableStateOf(false) }
            var working by remember { mutableStateOf(false) }
            SubPage(stringResource(R.string.adminContestNew), back = { navigate(ContestAdminRoute.List) }) {
                ContestAdminNew(
                    draft, showsErrors, working, onDraft = { draft = it },
                    onPickEnd = {
                        val zone = ZoneId.of("Europe/Prague")
                        val at = draft.endsAt.atZone(zone)
                        DatePickerDialog(context, { _, y, m, d ->
                            TimePickerDialog(context, { _, h, min ->
                                draft = draft.copy(endsAt = java.time.LocalDateTime.of(y, m + 1, d, h, min).atZone(zone).toInstant())
                            }, at.hour, at.minute, true).show()
                        }, at.year, at.monthValue - 1, at.dayOfMonth).apply { datePicker.minDate = System.currentTimeMillis() }.show()
                    },
                    onReview = { if (draft.problems().isEmpty()) confirming = true else showsErrors = true },
                )
            }
            if (confirming) {
                ModalBottomSheet(
                    onDismissRequest = { confirming = false },
                    sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
                    containerColor = Theme.statsCard,
                    shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
                ) {
                    ContestLaunchConfirmation(draft, working, onEdit = { confirming = false }, onLaunch = {
                        working = true
                        scope.launch {
                            try {
                                admin.create(draft)
                                toast(context.getString(R.string.adminContestStarted), Icons.Rounded.CheckCircle)
                                confirming = false
                                navigate(ContestAdminRoute.List)
                            } catch (e: AccountError) {
                                confirming = false
                                toastError(e)
                            } finally { working = false }
                        }
                    })
                }
            }
        }
        is ContestAdminRoute.Detail -> {
            var detail by remember(route.id) { mutableStateOf<ContestAdmin.Detail?>(null) }
            var drawing by remember { mutableStateOf(false) }
            LaunchedEffect(route.id) { try { detail = admin.detail(route.id) } catch (e: AccountError) { toastError(e) } }
            SubPage(stringResource(R.string.adminContests), back = { navigate(ContestAdminRoute.List) }) {
                ContestAdminDetail(
                    detail, drawing,
                    onDraw = { count ->
                        drawing = true
                        scope.launch {
                            try { detail = admin.draw(route.id, count) } catch (e: AccountError) { toastError(e) } finally { drawing = false }
                        }
                    },
                    onExport = {
                        val d = detail ?: return@ContestAdminDetail
                        val send = Intent(Intent.ACTION_SEND).apply {
                            type = "text/csv"
                            putExtra(Intent.EXTRA_SUBJECT, d.summary.title)
                            putExtra(Intent.EXTRA_TEXT, d.csv)
                        }
                        runCatching { context.startActivity(Intent.createChooser(send, null)) }
                    },
                    onPhone = { phone, action ->
                        when (action) {
                            PhoneAction.COPY -> scope.launch {
                                clipboard.setClipEntry(ClipEntry(ClipData.newPlainText("phone", phone)))
                                toast(context.getString(R.string.adminContestPhoneCopied), Icons.Rounded.CheckCircle)
                            }
                            PhoneAction.CALL -> runCatching { context.startActivity(Intent(Intent.ACTION_DIAL, Uri.parse("tel:$phone"))) }
                            PhoneAction.SMS -> runCatching { context.startActivity(Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:$phone"))) }
                        }
                    },
                )
            }
        }
    }
}
