import SwiftUI
import UIKit

/// The gift with sparkles and a soft glow (Figma "Soutěž/Ilustrace"), in the
/// spirit of the sleep timer's moon. `onYellow` for the home card, else for
/// the dark contest screens.
struct ContestIllustration: View {
    var onYellow = false
    var size: CGFloat = 96

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [onYellow ? Color.white.opacity(0.75) : Color(hex: 0x6A5BC2, alpha: 0.6), .clear],
                    center: .center, startRadius: 0, endRadius: size * 0.46
                ))
                .frame(width: size * 0.92, height: size * 0.92)
                .offset(y: size * 0.04)
            Image("ContestSparkles")
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(onYellow ? Theme.brandPurple : Color(hex: 0xCFC6FF))
            Image("ContestGift")
                .resizable()
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The yellow card between the player and the chat (Figma H1).
struct ContestInfobox: View {
    let contest: ContestService.Contest
    let onOpen: () -> Void
    let onClose: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .center, spacing: Theme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.contestBadge)
                        .font(Theme.Typography.Manrope.extraBold(size: 11, relativeTo: .caption2))
                        .tracking(0.8)
                        .foregroundStyle(Theme.sunYellow)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.background, in: Capsule())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(contest.title)
                            .font(Theme.Typography.Manrope.extraBold(size: 18, relativeTo: .headline))
                            .foregroundStyle(Theme.background)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(L10n.contestUntil(ContestFormat.dayAndTime(contest.endsAt)))
                            .font(Theme.Typography.Copy.label)
                            .foregroundStyle(Theme.background.opacity(0.7))
                    }
                    HStack(spacing: 6) {
                        Text(L10n.contestJoin)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.sunYellow)
                    }
                    .font(Theme.Typography.Manrope.extraBold(size: 14, relativeTo: .subheadline))
                    .foregroundStyle(.white)
                    .padding(.leading, 16)
                    .padding(.trailing, 14)
                    .padding(.vertical, 10)
                    .background(Theme.background, in: Capsule())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ContestIllustration(onYellow: true)
            }
            .padding(.leading, 18)
            .padding(.trailing, 14)
            .padding(.vertical, 18)
            .background(Theme.sunYellow, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(L10n.contestBadge), \(contest.title), \(L10n.contestUntil(ContestFormat.dayAndTime(contest.endsAt)))")
        .accessibilityHint(L10n.contestJoin)
        .accessibilityIdentifier("contest.infobox")
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Theme.background)
                    .frame(width: 28, height: 28)
                    .background(Theme.background.opacity(0.1), in: Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(2)
            .accessibilityLabel(L10n.contestCloseLabel)
            .accessibilityIdentifier("contest.close")
        }
    }
}

/// The contest's own page, as a sheet over the home screen (Figma D1–D9).
struct ContestSheetView: View {
    let snapshot: ContestService.Contest

    @ObservedObject private var service = ContestService.shared
    @ObservedObject private var account = AccountService.shared
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selected: String?
    @State private var answerText = ""
    @State private var phone = ""
    @State private var showsErrors = false
    @State private var serverPhoneError = false
    @State private var isSending = false
    @State private var sendFailed = false
    @State private var closedByServer = false
    @State private var justSent: ContestService.Entry?
    @State private var registerReason: RegisterReason?
    @State private var isShowingRules = false
    @FocusState private var focus: Field?

    private enum Field { case answer, phone }
    private struct RegisterReason: Identifiable { let id = "contest" }
    private static let letters = ["A", "B", "C"]

    private var contest: ContestService.Contest {
        if let current = service.current, current.id == snapshot.id { return current }
        return snapshot
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                HStack {
                    Spacer()
                    HeaderIconButton(systemName: "xmark") { dismiss() }
                        .accessibilityLabel(L10n.close)
                        .accessibilityIdentifier("contest.sheet.close")
                }
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 36)
            .animation(Motion.smoothOut(Motion.medium), value: stateKey)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background.ignoresSafeArea())
        // The phone pad has no return key.
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L10n.nicknameDone) { focus = nil }
                    .font(Theme.Typography.Copy.link)
            }
        }
        .sheet(item: $registerReason) { reason in
            RegisterSheet(reason: reason.id)
                .appTextSizeLimit()
        }
        .sheet(isPresented: $isShowingRules) {
            if let url = contest.rulesURL { SafariView(url: url) }
        }
        .onChange(of: account.isSignedIn) { _, _ in
            Task { await service.refresh() }
        }
        .task { await service.refresh() }
    }

    private var stateKey: String {
        if justSent != nil { return "sent" }
        if contest.myStatus == .entered { return "entered" }
        if closedByServer || !contest.isRunning { return "ended" }
        return account.isSignedIn ? "form" : "gate"
    }

    @ViewBuilder
    private var content: some View {
        if let entry = justSent {
            result(title: L10n.contestSentTitle, body: L10n.contestSentBody(ContestFormat.dayAndTime(contest.endsAt)), entry: entry, sent: true)
                .transition(.reveal)
        } else if contest.myStatus == .entered, let entry = contest.myEntry {
            result(title: L10n.contestEnteredTitle, body: L10n.contestEnteredBody, entry: entry, sent: false)
                .transition(.reveal)
        } else if closedByServer || !contest.isRunning {
            result(title: L10n.contestEndedTitle, body: L10n.contestEndedBody, entry: nil, sent: false, dim: true)
                .transition(.reveal)
        } else {
            details
            if account.isSignedIn {
                form.transition(.reveal)
            } else {
                gate.transition(.reveal)
            }
        }
    }

    // MARK: - Text of the contest

    @ViewBuilder
    private var details: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.contestBadge)
                    .font(Theme.Typography.Manrope.extraBold(size: 11, relativeTo: .caption2))
                    .tracking(0.8)
                    .foregroundStyle(Theme.background)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.sunYellow, in: Capsule())
                Text(contest.title)
                    .font(Theme.Typography.Heading.page)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ContestIllustration()
        }
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { facts }
            VStack(alignment: .leading, spacing: 8) { facts }
        }
        Text(contest.body)
            .font(Theme.Typography.Manrope.semibold(size: 15, relativeTo: .body))
            .foregroundStyle(Theme.mutedText)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
        if contest.rulesURL != nil {
            Button { isShowingRules = true } label: {
                HStack(spacing: 6) {
                    Text(L10n.contestRules)
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.mutedText)
                }
                .font(Theme.Typography.Copy.link)
                .foregroundStyle(Theme.textPrimary)
            }
            .buttonStyle(.plain)
        }
        ListDivider()
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.contestQuestion)
                .font(Theme.Typography.Manrope.extraBold(size: 12, relativeTo: .caption))
                .tracking(0.8)
                .foregroundStyle(Theme.gold)
            Text(contest.question)
                .font(Theme.Typography.Heading.section)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var facts: some View {
        fact(L10n.contestFactUntil, ContestFormat.dayAndTime(contest.endsAt))
        if !contest.prize.isEmpty { fact(L10n.contestFactPrize, contest.prize) }
    }

    private func fact(_ key: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(key).foregroundStyle(Theme.subtleText)
            Text(value).font(Theme.Typography.Manrope.bold(size: 13, relativeTo: .footnote)).foregroundStyle(Theme.textPrimary)
        }
        .font(Theme.Typography.Copy.label)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.statsCard, in: Capsule())
        .overlay(Capsule().stroke(Theme.divider, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    // MARK: - D1: only for Slowriders

    private var gate: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.contestGateTitle)
                .font(Theme.Typography.Heading.item)
                .foregroundStyle(Theme.textPrimary)
            Text(L10n.contestGateBody)
                .font(Theme.Typography.Copy.body)
                .foregroundStyle(Theme.mutedText)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryActionButton(title: L10n.contestGateButton) { registerReason = RegisterReason() }
                .padding(.top, 4)
                .accessibilityIdentifier("contest.signIn")
        }
        .padding(20)
        .background(Theme.statsCard, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).stroke(Theme.sunYellow.opacity(0.5), lineWidth: 1))
    }

    // MARK: - D2–D5, D7: the form

    private var answerProblem: String? {
        guard showsErrors else { return nil }
        if contest.answerType == .choice { return selected == nil ? L10n.contestErrorPickOption : nil }
        return answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? L10n.contestErrorAnswer : nil
    }

    private var phoneProblem: String? {
        guard showsErrors else { return nil }
        return serverPhoneError || ContestService.normalizedPhone(phone) == nil ? L10n.contestErrorPhone : nil
    }

    private var hasAnything: Bool {
        selected != nil || !answerText.trimmingCharacters(in: .whitespaces).isEmpty || !phone.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Group {
                if contest.answerType == .choice {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(contest.options.prefix(3).enumerated()), id: \.offset) { index, option in
                            optionRow(letter: Self.letters[index], text: option)
                        }
                        if let answerProblem { errorLine(answerProblem) }
                    }
                } else {
                    ContestTextField(label: L10n.contestAnswerLabel, placeholder: L10n.contestAnswerPlaceholder, text: $answerText,
                                     hint: nil, error: answerProblem)
                        .focused($focus, equals: .answer)
                        .submitLabel(.next)
                        .onSubmit { focus = .phone }
                }
                ContestTextField(label: L10n.contestPhoneLabel, placeholder: "+420 777 123 456", text: $phone,
                                 hint: L10n.contestPhoneHint, error: phoneProblem, keyboard: .phonePad, contentType: .telephoneNumber)
                    .focused($focus, equals: .phone)
                    .onChange(of: phone) { _, _ in
                        serverPhoneError = false
                        showsErrors = false
                    }
                Text(L10n.contestConsent)
                    .font(Theme.Typography.Manrope.semibold(size: 12, relativeTo: .caption))
                    .foregroundStyle(Theme.subtleText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .disabled(isSending)
            .opacity(isSending ? 0.5 : 1)

            if sendFailed {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.liveRed)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.contestSendFailedTitle).font(Theme.Typography.Manrope.bold(size: 14, relativeTo: .subheadline)).foregroundStyle(Theme.textPrimary)
                        Text(L10n.contestSendFailedBody).font(Theme.Typography.Copy.label).foregroundStyle(Theme.mutedText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(Theme.liveRed.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.liveRed.opacity(0.6), lineWidth: 1))
                .transition(.reveal)
                .accessibilityElement(children: .combine)
            }

            Button(action: send) {
                HStack(spacing: 10) {
                    if isSending { ProgressView().tint(.white) }
                    Text(isSending ? L10n.contestSending : (sendFailed ? L10n.contestRetry : L10n.contestSubmit))
                }
                .font(Theme.Typography.Copy.button)
                .foregroundStyle(.white.opacity(hasAnything ? 1 : 0.6))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Theme.liveRed.opacity(hasAnything ? 1 : 0.35), in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!hasAnything || isSending)
            .accessibilityIdentifier("contest.submit")
        }
    }

    private func optionRow(letter: String, text: String) -> some View {
        let isSelected = selected == letter
        let isError = answerProblem != nil
        return Button {
            selected = letter
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 12) {
                Text(letter)
                    .font(Theme.Typography.Manrope.extraBold(size: 14, relativeTo: .subheadline))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(isSelected ? Theme.liveRed : Theme.divider, in: Circle())
                Text(text)
                    .font(Theme.Typography.Manrope.semibold(size: 16, relativeTo: .body))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 14)
            .padding(.trailing, 16)
            .padding(.vertical, 14)
            .background(isSelected ? Color(hex: 0x2C1A3A) : Theme.statsCardRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected || isError ? Theme.liveRed : Theme.divider, lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("contest.option.\(letter)")
    }

    private func errorLine(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typography.Copy.label)
            .foregroundStyle(Theme.liveRed)
            .transition(.opacity)
    }

    private func send() {
        let answer = contest.answerType == .choice ? (selected ?? "") : answerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty, ContestService.normalizedPhone(phone) != nil else {
            withAnimation(Motion.smoothOut(Motion.fast)) { showsErrors = true }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        focus = nil
        isSending = true
        Task {
            defer { isSending = false }
            do {
                let entry = try await service.enter(contest, answer: answer, phone: phone)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(Motion.smoothOut(Motion.medium)) {
                    sendFailed = false
                    justSent = entry
                }
            } catch let failure as ContestService.Failure {
                withAnimation(Motion.smoothOut(Motion.medium)) {
                    switch failure {
                    case .closed: closedByServer = true
                    case .alreadyEntered: break // `current` now says entered → D9
                    case .phoneInvalid: serverPhoneError = true; showsErrors = true
                    case .answerInvalid: showsErrors = true
                    case .accountRequired: registerReason = RegisterReason()
                    case .offline, .other: sendFailed = true
                    }
                }
            } catch {
                sendFailed = true
            }
        }
    }

    // MARK: - D6, D8, D9

    private func result(title: String, body: String, entry: ContestService.Entry?, sent: Bool, dim: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            VStack(spacing: 14) {
                ContestIllustration(size: 150)
                    .opacity(dim ? 0.45 : 1)
                Text(title)
                    .font(Theme.Typography.Manrope.extraBold(size: 26, relativeTo: .title))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text(body)
                    .font(Theme.Typography.Manrope.semibold(size: 15, relativeTo: .body))
                    .foregroundStyle(Theme.mutedText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, Theme.Spacing.lg)
            .accessibilityElement(children: .combine)

            if let entry {
                VStack(alignment: .leading, spacing: 12) {
                    Text(contest.title)
                        .font(Theme.Typography.Manrope.extraBold(size: 15, relativeTo: .headline))
                        .foregroundStyle(Theme.textPrimary)
                    summaryRow(L10n.contestSummaryAnswer, contest.answerLabel(entry.answer))
                    if sent, let phone = entry.phone { summaryRow(L10n.contestSummaryPhone, ContestFormat.phone(phone)) }
                    if !sent, let at = entry.createdAt { summaryRow(L10n.contestSummarySent, ContestFormat.dayTimeShort(at)) }
                    summaryRow(L10n.contestSummaryDraw, L10n.contestDrawAfter(ContestFormat.day(contest.endsAt)))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.statsCard, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            }

            PrimaryActionButton(title: L10n.contestBackToRadio) { dismiss() }
                .padding(.top, Theme.Spacing.sm)
        }
    }

    private func summaryRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(key).font(Theme.Typography.Copy.body).foregroundStyle(Theme.subtleText)
            Spacer(minLength: 8)
            Text(value)
                .font(Theme.Typography.Manrope.bold(size: 14, relativeTo: .subheadline))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A labelled field on the contest screens and the admin form
/// (Figma "Formulář/Pole").
struct ContestTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var hint: String?
    var error: String?
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var multiline = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(Theme.Typography.Manrope.bold(size: 14, relativeTo: .subheadline))
                .foregroundStyle(Theme.textPrimary)
            Group {
                if multiline {
                    TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(Theme.subtleText), axis: .vertical)
                        .lineLimit(4...12)
                        .padding(.vertical, 14)
                } else {
                    TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(Theme.subtleText))
                        .frame(height: 52)
                }
            }
            .font(Theme.Typography.Manrope.semibold(size: 16, relativeTo: .body))
            .foregroundStyle(Theme.textPrimary)
            .tint(Theme.liveRed)
            .keyboardType(keyboard)
            .textContentType(contentType)
            .autocorrectionDisabled(keyboard != .default)
            .padding(.horizontal, 16)
            .background(Theme.statsCardRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(error != nil ? Theme.liveRed : Theme.divider, lineWidth: error != nil ? 2 : 1)
            )
            .accessibilityLabel(label)
            if let line = error ?? hint {
                Text(line)
                    .font(Theme.Typography.Copy.label)
                    .foregroundStyle(error != nil ? Theme.liveRed : Theme.subtleText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
