import SwiftUI
import UIKit

/// Routes inside Profil for Správa ▸ Soutěže (Figma "Soutěže" S1–S6).
enum ContestAdminRoute: Hashable {
    case list
    case new
    case detail(Int64)
}

@MainActor
private func contestToast(_ message: String, image: String = "exclamationmark.circle") {
    ToastCenter.shared.show(.init(systemImage: image, message: message))
}

private func contestChip(_ text: String, fill: Color, color: Color) -> some View {
    Text(text)
        .font(Theme.Typography.Manrope.extraBold(size: 11, relativeTo: .caption2))
        .tracking(0.6)
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(fill, in: Capsule())
}

private func contestStat(_ value: Int, _ label: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
        Text("\(value)")
            .font(Theme.Typography.Manrope.extraBold(size: 20, relativeTo: .title3))
            .foregroundStyle(Theme.textPrimary)
            .monospacedDigit()
        Text(label)
            .font(Theme.Typography.Manrope.semibold(size: 12, relativeTo: .caption))
            .foregroundStyle(Theme.subtleText)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Theme.statsCardRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .accessibilityElement(children: .combine)
}

private func contestRow(_ title: String, _ subtitle: String?, subtitleColor: Color = Theme.subtleText) -> some View {
    HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(Theme.Typography.Manrope.semibold(size: 16, relativeTo: .body))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.leading)
            if let subtitle {
                Text(subtitle)
                    .font(Theme.Typography.Copy.label)
                    .foregroundStyle(subtitleColor)
                    .multilineTextAlignment(.leading)
            }
        }
        Spacer(minLength: 8)
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.mutedText)
    }
    .padding(.vertical, 12)
    .contentShape(Rectangle())
    .overlay(alignment: .bottom) { Rectangle().fill(Theme.divider).frame(height: 1) }
}

private func summarySubtitle(_ s: ContestAdmin.Summary) -> (String, Color) {
    let date = s.endTime.map(ContestFormat.day) ?? ""
    let line = s.endedEarly ? L10n.adminContestEndedEarlyRow(date, count: s.entries) : L10n.adminContestEndedRow(date, count: s.entries)
    if s.drawnAt == nil && s.entries > 0 { return ("\(line) · \(L10n.adminContestAwaitingDraw.lowercased())", Theme.gold) }
    return (line, Theme.subtleText)
}

// MARK: - S1 / S2 / S4

struct ContestAdminListView: View {
    @ObservedObject private var admin = ContestAdmin.shared
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var isConfirmingEnd = false

    var body: some View {
        AdminPage(title: L10n.adminContests) {
            Text(L10n.adminContestsBody)
                .font(Theme.Typography.Copy.body)
                .foregroundStyle(Theme.mutedText)
                .fixedSize(horizontal: false, vertical: true)

            if let current = admin.overview?.current {
                runningCard(current)
                Button { isConfirmingEnd = true } label: {
                    Text(L10n.adminContestEnd)
                        .font(Theme.Typography.Copy.button)
                        .foregroundStyle(Theme.liveRed)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.plain)
                .confirmationDialog(L10n.adminContestEndTitle, isPresented: $isConfirmingEnd, titleVisibility: .visible) {
                    Button(L10n.adminContestEnd, role: .destructive) { end(current) }
                    Button(L10n.adminContestKeepRunning, role: .cancel) {}
                } message: {
                    Text(L10n.adminContestEndBody)
                }
            } else if admin.overview != nil {
                VStack(spacing: 6) {
                    Text(L10n.adminContestNoneTitle)
                        .font(Theme.Typography.Heading.item)
                        .foregroundStyle(Theme.textPrimary)
                    Text(L10n.adminContestNoneBody)
                        .font(Theme.Typography.Copy.body)
                        .foregroundStyle(Theme.mutedText)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Theme.statsCard, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).stroke(Theme.divider, style: StrokeStyle(lineWidth: 1, dash: [6, 6])))
                NavigationLink(value: ProfileView.Route.contests(.new)) {
                    Text(L10n.adminContestNew)
                        .font(Theme.Typography.Copy.button)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Theme.liveRed, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("contests.new")
            } else {
                ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.top, Theme.Spacing.lg)
            }

            if let previous = admin.overview?.previous, !previous.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.adminContestPrevious)
                        .font(Theme.Typography.Heading.section)
                        .foregroundStyle(Theme.textPrimary)
                    VStack(spacing: 0) {
                        ForEach(previous) { s in
                            NavigationLink(value: ProfileView.Route.contests(.detail(s.id))) {
                                let (line, color) = summarySubtitle(s)
                                contestRow(s.title, line, subtitleColor: color)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.top, Theme.Spacing.sm)
            }
        }
        .animation(Motion.smoothOut(Motion.medium), value: admin.overview)
        .task { do { try await admin.reload() } catch { contestToast(ContestAdmin.message(for: error)) } }
        .refreshable { try? await admin.reload() }
    }

    private func runningCard(_ s: ContestAdmin.Summary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            contestChip(L10n.adminContestRunningBadge, fill: Theme.sunYellow, color: Theme.background)
            Text(s.title)
                .font(Theme.Typography.Manrope.extraBold(size: 17, relativeTo: .headline))
                .foregroundStyle(Theme.textPrimary)
            Text(L10n.adminContestRunningInfo(s.startsAt.map(ContestFormat.day) ?? "", s.endsAt.map(ContestFormat.dayAndTime) ?? ""))
                .font(Theme.Typography.Copy.label)
                .foregroundStyle(Theme.mutedText)
            HStack(spacing: 8) {
                contestStat(s.entries, L10n.adminContestEntries)
                if s.answerType == "choice" { contestStat(s.correct, L10n.adminContestCorrect) }
                contestStat(s.dismissed, L10n.adminContestDismissed)
            }
            NavigationLink(value: ProfileView.Route.contests(.detail(s.id))) {
                HStack {
                    Text(L10n.adminContestAnswersRow)
                        .font(Theme.Typography.Manrope.semibold(size: 16, relativeTo: .body))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.mutedText)
                }
                .padding(.top, 10)
                .contentShape(Rectangle())
                .overlay(alignment: .top) { Rectangle().fill(Theme.divider).frame(height: 1) }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Theme.statsCard, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).stroke(Theme.sunYellow.opacity(0.45), lineWidth: 1))
    }

    private func end(_ s: ContestAdmin.Summary) {
        Task {
            do {
                try await admin.end(s.id)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                contestToast(L10n.adminContestEndedToast, image: "checkmark.circle")
            } catch {
                contestToast(ContestAdmin.message(for: error))
            }
        }
    }
}

// MARK: - S3 / S3b / S3c

struct ContestAdminNewView: View {
    @ObservedObject private var admin = ContestAdmin.shared
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ContestAdmin.Draft()
    @State private var showsErrors = false
    @State private var isConfirming = false
    @State private var isWorking = false

    private var problems: Set<ContestAdmin.Draft.Field> { showsErrors ? draft.problems() : [] }

    var body: some View {
        AdminPage(title: L10n.adminContestNew) {
            ContestTextField(label: L10n.adminContestFieldTitle, placeholder: "", text: $draft.title,
                             hint: "\(draft.title.count)/60 · \(L10n.adminContestFieldTitleHint)",
                             error: problems.contains(.title) ? L10n.adminContestErrorRequired : nil)
            ContestTextField(label: L10n.adminContestFieldBody, placeholder: "", text: $draft.body,
                             hint: L10n.adminContestFieldBodyHint,
                             error: problems.contains(.body) ? L10n.adminContestErrorRequired : nil, multiline: true)
            ContestTextField(label: L10n.adminContestFieldQuestion, placeholder: "", text: $draft.question,
                             error: problems.contains(.question) ? L10n.adminContestErrorRequired : nil)
            typePicker
            if draft.isChoice { options.transition(.reveal) } else {
                Text(L10n.adminContestTextHint)
                    .font(Theme.Typography.Copy.label)
                    .foregroundStyle(Theme.subtleText)
            }
            HStack(alignment: .top, spacing: 12) {
                ContestTextField(label: L10n.adminContestFieldPrize, placeholder: "", text: $draft.prize,
                                 hint: L10n.adminContestFieldPrizeHint,
                                 error: problems.contains(.prize) ? L10n.adminContestErrorRequired : nil)
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.adminContestFieldWinners)
                        .font(Theme.Typography.Manrope.bold(size: 14, relativeTo: .subheadline))
                        .foregroundStyle(Theme.textPrimary)
                    Stepper(value: $draft.winnersCount, in: 1...20) {
                        Text("\(draft.winnersCount)")
                            .font(Theme.Typography.Manrope.semibold(size: 16, relativeTo: .body))
                            .foregroundStyle(Theme.textPrimary)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 52)
                    .background(Theme.statsCardRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.divider, lineWidth: 1))
                }
                .frame(width: 150)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.adminContestFieldEnd)
                    .font(Theme.Typography.Manrope.bold(size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.textPrimary)
                DatePicker("", selection: $draft.endsAt, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .tint(Theme.liveRed)
                    .environment(\.timeZone, ScheduleStore.stationCalendar.timeZone)
                    .environment(\.locale, Locale(identifier: L10n.isEnglish ? "en_GB" : "cs_CZ"))
                Text(problems.contains(.endsAt) ? L10n.adminContestErrorEnd : L10n.adminContestFieldEndHint)
                    .font(Theme.Typography.Copy.label)
                    .foregroundStyle(problems.contains(.endsAt) ? Theme.liveRed : Theme.subtleText)
            }
            ContestTextField(label: L10n.adminContestFieldRules, placeholder: "slowdownradijo.cz/pravidla-soutezi", text: $draft.rulesURL,
                             hint: L10n.adminContestFieldRulesHint,
                             error: problems.contains(.rulesURL) ? L10n.adminContestErrorRules : nil,
                             keyboard: .URL, contentType: .URL)
                .textInputAutocapitalization(.never)
            PrimaryActionButton(title: L10n.adminContestReview, isEnabled: !isWorking) {
                if draft.problems().isEmpty {
                    isConfirming = true
                } else {
                    withAnimation(Motion.smoothOut(Motion.fast)) { showsErrors = true }
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
            .accessibilityIdentifier("contests.review")
        }
        .animation(Motion.smoothOut(Motion.medium), value: draft.isChoice)
        .sheet(isPresented: $isConfirming) { confirmation }
    }

    private var typePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.adminContestAnswerType)
                .font(Theme.Typography.Manrope.bold(size: 14, relativeTo: .subheadline))
                .foregroundStyle(Theme.textPrimary)
            HStack(spacing: 4) {
                ForEach([true, false], id: \.self) { choice in
                    Button { draft.isChoice = choice } label: {
                        Text(choice ? L10n.adminContestTypeChoice : L10n.adminContestTypeText)
                            .font(Theme.Typography.Manrope.extraBold(size: 14, relativeTo: .subheadline))
                            .foregroundStyle(draft.isChoice == choice ? .white : Theme.mutedText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(draft.isChoice == choice ? Theme.liveRed : .clear, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(draft.isChoice == choice ? .isSelected : [])
                }
            }
            .padding(4)
            .background(Theme.statsCardRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.adminContestOptions)
                .font(Theme.Typography.Manrope.bold(size: 14, relativeTo: .subheadline))
                .foregroundStyle(Theme.textPrimary)
            ForEach(0..<3, id: \.self) { index in
                let letter = ["A", "B", "C"][index]
                let isCorrect = draft.correctOption == index
                HStack(spacing: 12) {
                    Text(letter)
                        .font(Theme.Typography.Manrope.extraBold(size: 14, relativeTo: .subheadline))
                        .foregroundStyle(Theme.mutedText)
                    TextField("", text: $draft.options[index], prompt: Text(L10n.adminContestOptionPlaceholder(letter)).foregroundStyle(Theme.subtleText))
                        .font(Theme.Typography.Manrope.semibold(size: 16, relativeTo: .body))
                        .foregroundStyle(Theme.textPrimary)
                        .tint(Theme.liveRed)
                    Button { draft.correctOption = index } label: {
                        Image(systemName: isCorrect ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundStyle(isCorrect ? Theme.spotifyGreen : Theme.statsBarMuted)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.adminContestCorrectMark)
                    .accessibilityAddTraits(isCorrect ? .isSelected : [])
                }
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(Theme.statsCardRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(problems.contains(.options) && draft.options[index].trimmingCharacters(in: .whitespaces).isEmpty
                                ? Theme.liveRed : (isCorrect ? Theme.spotifyGreen : Theme.divider), lineWidth: 1)
                )
            }
            Text(problems.contains(.options) ? L10n.adminContestErrorOptions : L10n.adminContestOptionsHint)
                .font(Theme.Typography.Copy.label)
                .foregroundStyle(problems.contains(.options) ? Theme.liveRed : Theme.subtleText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var confirmation: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.adminContestLaunchTitle)
                    .font(Theme.Typography.Heading.hero)
                    .foregroundStyle(Theme.textPrimary)
                Text(L10n.adminContestLaunchPreview)
                    .font(Theme.Typography.Copy.body)
                    .foregroundStyle(Theme.mutedText)
                ContestInfobox(contest: draft.preview, onOpen: {}, onClose: {})
                    .allowsHitTesting(false)
                Text(L10n.adminContestLaunchBody)
                    .font(Theme.Typography.Copy.body)
                    .foregroundStyle(Theme.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
                PrimaryActionButton(title: L10n.adminContestLaunch, isEnabled: !isWorking) { launch() }
                    .accessibilityIdentifier("contests.launch")
                SecondaryActionButton(title: L10n.adminContestEdit) { isConfirming = false }
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.statsCard)
        .appTextSizeLimit()
    }

    private func launch() {
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await admin.create(draft)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                contestToast(L10n.adminContestStarted, image: "checkmark.circle")
                isConfirming = false
                dismiss()
            } catch {
                isConfirming = false
                contestToast(ContestAdmin.message(for: error))
            }
        }
    }
}

// MARK: - S5 / S6

struct ContestAdminDetailView: View {
    let contestID: Int64

    @ObservedObject private var admin = ContestAdmin.shared
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.openURL) private var openURL
    @State private var detail: ContestAdmin.Detail?
    @State private var isDrawing = false
    @State private var csvURL: URL?

    var body: some View {
        AdminPage(title: L10n.adminContests) {
            if let detail {
                content(detail)
            } else {
                ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.top, Theme.Spacing.lg)
            }
        }
        .animation(Motion.smoothOut(Motion.medium), value: detail)
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private func content(_ d: ContestAdmin.Detail) -> some View {
        let s = d.summary
        VStack(alignment: .leading, spacing: 10) {
            if s.isRunning {
                contestChip(L10n.adminContestRunningBadge, fill: Theme.sunYellow, color: Theme.background)
            } else {
                contestChip(L10n.adminContestEndedOn(s.endTime.map(ContestFormat.day) ?? ""), fill: Theme.divider, color: Theme.mutedText)
            }
            Text(s.title)
                .font(Theme.Typography.Heading.page)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(d.question)
                .font(Theme.Typography.Copy.body)
                .foregroundStyle(Theme.mutedText)
        }
        HStack(spacing: 8) {
            contestStat(s.entries, L10n.adminContestEntries)
            if s.answerType == "choice" { contestStat(s.correct, L10n.adminContestCorrect) }
            contestStat(s.winners, L10n.adminContestWinnersCount)
        }

        if !d.winners.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.adminContestWinners)
                    .font(Theme.Typography.Heading.section)
                    .foregroundStyle(Theme.textPrimary)
                Text(L10n.adminContestWinnersBody)
                    .font(Theme.Typography.Copy.body)
                    .foregroundStyle(Theme.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(d.winners) { winner in winnerCard(winner, d) }
                SecondaryActionButton(title: L10n.adminContestDrawAgain) { draw(count: 1) }
                    .disabled(isDrawing)
            }
        }

        if s.answerType == "choice", s.entries > 0 {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.adminContestDistribution)
                    .font(Theme.Typography.Heading.section)
                    .foregroundStyle(Theme.textPrimary)
                ForEach(0..<min(3, d.options.count), id: \.self) { index in
                    distributionBar(d, index: index)
                }
            }
        }

        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.adminContestAnswers)
                .font(Theme.Typography.Heading.section)
                .foregroundStyle(Theme.textPrimary)
            if d.entries.isEmpty {
                Text(L10n.adminContestNoAnswers)
                    .font(Theme.Typography.Copy.body)
                    .foregroundStyle(Theme.mutedText)
                    .padding(.vertical, 8)
            }
            LazyVStack(spacing: 0) {
                ForEach(d.entries) { e in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text((e.nickname ?? "—") + (e.isCorrect == true ? "  ✓" : ""))
                                .font(Theme.Typography.Manrope.semibold(size: 16, relativeTo: .body))
                                .foregroundStyle(Theme.textPrimary)
                            Text([d.answerLabel(e.answer), e.phone.map(ContestFormat.phone)].compactMap { $0 }.joined(separator: " · "))
                                .font(Theme.Typography.Copy.label)
                                .foregroundStyle(Theme.subtleText)
                                .textSelection(.enabled)
                        }
                        Spacer(minLength: 8)
                        Text(e.at.map(ContestFormat.dayTimeShort) ?? "")
                            .font(Theme.Typography.Copy.label)
                            .foregroundStyle(Theme.mutedText)
                    }
                    .padding(.vertical, 12)
                    .overlay(alignment: .bottom) { Rectangle().fill(Theme.divider).frame(height: 1) }
                    .accessibilityElement(children: .combine)
                }
            }
        }

        VStack(spacing: 12) {
            if !s.isRunning, d.winners.isEmpty, s.entries > 0 {
                PrimaryActionButton(title: L10n.adminContestDrawButton, isEnabled: !isDrawing) { draw(count: nil) }
                    .accessibilityIdentifier("contests.draw")
            }
            if let csvURL, !d.entries.isEmpty {
                ShareLink(item: csvURL) {
                    Text(L10n.adminContestExport)
                        .font(Theme.Typography.Copy.button)
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Theme.hairline(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, Theme.Spacing.sm)
    }

    private func winnerCard(_ w: ContestAdmin.Person, _ d: ContestAdmin.Detail) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(w.nickname ?? "—")
                .font(Theme.Typography.Manrope.bold(size: 14, relativeTo: .subheadline))
                .foregroundStyle(Theme.mutedText)
            if let phone = w.phone {
                Text(ContestFormat.phone(phone))
                    .font(Theme.Typography.Manrope.extraBold(size: 20, relativeTo: .title3))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
                    .textSelection(.enabled)
                    .contextMenu {
                        Button { UIPasteboard.general.string = phone; contestToast(L10n.adminContestPhoneCopied, image: "doc.on.doc") } label: {
                            Label(L10n.adminContestCopyPhone, systemImage: "doc.on.doc")
                        }
                        Button { if let url = URL(string: "tel:\(phone)") { openURL(url) } } label: {
                            Label(L10n.adminContestCall, systemImage: "phone")
                        }
                        Button { if let url = URL(string: "sms:\(phone)") { openURL(url) } } label: {
                            Label(L10n.adminContestSMS, systemImage: "message")
                        }
                    }
            } else {
                Text(L10n.adminContestPhoneDeleted)
                    .font(Theme.Typography.Copy.body)
                    .foregroundStyle(Theme.subtleText)
            }
            if let answer = w.answer {
                Text(d.answerLabel(answer))
                    .font(Theme.Typography.Copy.label)
                    .foregroundStyle(Theme.subtleText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.statsCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func distributionBar(_ d: ContestAdmin.Detail, index: Int) -> some View {
        let letter = ["A", "B", "C"][index]
        let count = d.distribution[letter] ?? 0
        let total = max(1, d.summary.entries)
        let share = Double(count) / Double(total)
        let isCorrect = d.correctOption == index
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(letter) · \(d.options[index])" + (isCorrect ? "  ✓ \(L10n.adminContestCorrectMark)" : ""))
                    .font(Theme.Typography.Manrope.bold(size: 14, relativeTo: .subheadline))
                    .foregroundStyle(isCorrect ? Theme.spotifyGreen : Theme.textPrimary)
                Spacer(minLength: 8)
                Text("\(count) · \(Int((share * 100).rounded())) %")
                    .font(Theme.Typography.Copy.label)
                    .foregroundStyle(Theme.mutedText)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.statsCardRaised)
                    Capsule().fill(isCorrect ? Theme.spotifyGreen : Theme.statsBarMuted)
                        .frame(width: max(4, geo.size.width * share))
                }
            }
            .frame(height: 8)
        }
        .accessibilityElement(children: .combine)
    }

    private func load() async {
        do {
            let loaded = try await admin.detail(contestID)
            detail = loaded
            writeCSV(loaded)
        } catch {
            contestToast(ContestAdmin.message(for: error))
        }
    }

    private func draw(count: Int?) {
        isDrawing = true
        Task {
            defer { isDrawing = false }
            do {
                let updated = try await admin.draw(contestID, count: count)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                detail = updated
                writeCSV(updated)
            } catch {
                contestToast(ContestAdmin.message(for: error))
            }
        }
    }

    private func writeCSV(_ d: ContestAdmin.Detail) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("soutez-\(contestID).csv")
        do {
            try d.csv.write(to: url, atomically: true, encoding: .utf8)
            csvURL = url
        } catch {
            csvURL = nil
        }
    }
}
