import SwiftUI

/// The nickname field with its live check (Figma Profil R1, N1–N3, chat J1–J3):
/// counter, a check / warning mark, the reason under it and the rules.
/// The format is checked here; whether it's free, by `nickname_available`.
struct NicknameField: View {
    @Binding var text: String
    @Binding var status: Status
    var isLocked = false
    var currentNickname: String? = nil

    enum Status: Equatable {
        case empty, checking, ok, invalid, taken, reserved, unchanged

        var canSave: Bool { self == .ok }
    }

    @ObservedObject private var loc = LocalizationManager.shared
    @FocusState private var isFocused: Bool

    private static let pattern = /^[A-Za-z0-9._]{3,20}$/

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.profileNickname)
                    .font(Theme.Typography.Manrope.extraBold(size: 13, relativeTo: .footnote))
                    .foregroundStyle(Theme.mutedText)
                Spacer()
                if !isLocked {
                    Text("\(text.count)/20")
                        .font(Theme.Typography.Copy.label)
                        .foregroundStyle(Theme.subtleText)
                        .monospacedDigit()
                }
            }

            HStack(spacing: 8) {
                TextField(L10n.nicknamePlaceholder, text: $text)
                    .font(Theme.Typography.Copy.reading)
                    .foregroundStyle(isLocked ? Theme.subtleText : Theme.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.username)
                    .focused($isFocused)
                    .disabled(isLocked)
                statusMark
            }
            .padding(.horizontal, 16)
            .frame(height: 50)
            .background(isLocked ? Theme.statsCard : Theme.statsCardRaised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1.5)
            )

            if let message {
                Text(message)
                    .font(Theme.Typography.Manrope.bold(size: 13, relativeTo: .footnote))
                    .foregroundStyle(status == .ok ? Theme.spotifyGreen : Theme.liveRed)
            }
        }
        .task(id: text) { await check() }
    }

    @ViewBuilder
    private var statusMark: some View {
        switch status {
        case _ where isLocked:
            Image(systemName: "lock.fill").foregroundStyle(Theme.subtleText)
        case .checking:
            ProgressView().controlSize(.small).tint(Theme.mutedText)
        case .ok:
            Image(systemName: "checkmark").foregroundStyle(Theme.spotifyGreen)
        case .invalid, .taken, .reserved:
            Image(systemName: "exclamationmark.circle").foregroundStyle(Theme.liveRed)
        default:
            EmptyView()
        }
    }

    private var borderColor: Color {
        if isLocked { return .clear }
        switch status {
        case .ok: return Theme.spotifyGreen
        case .invalid, .taken, .reserved: return Theme.liveRed
        default: return isFocused ? Theme.mutedText.opacity(0.6) : .clear
        }
    }

    private var message: String? {
        switch status {
        case .ok: return L10n.nicknameAvailable
        case .taken: return L10n.nicknameTaken
        case .reserved: return L10n.nicknameReserved
        case .invalid: return L10n.nicknameInvalid
        default: return nil
        }
    }

    private func check() async {
        let nick = text.trimmingCharacters(in: .whitespaces)
        if isLocked { return }
        if nick.isEmpty { status = .empty; return }
        if nick == currentNickname { status = .unchanged; return }
        guard nick.wholeMatch(of: Self.pattern) != nil else { status = .invalid; return }
        status = .checking
        try? await Task.sleep(for: .milliseconds(400))
        guard !Task.isCancelled else { return }
        do {
            switch try await AccountService.shared.checkNickname(nick) {
            case .ok: status = .ok
            case .taken: status = .taken
            case .reserved: status = .reserved
            case .invalid: status = .invalid
            }
        } catch {
            // Offline: let the server decide on save.
            status = .ok
        }
    }
}

/// "Ještě přezdívka" — right after the first sign-in (Figma Profil R1).
struct NicknameSetupView: View {
    var onDone: () -> Void = {}

    @ObservedObject private var loc = LocalizationManager.shared
    @State private var nickname = ""
    @State private var status: NicknameField.Status = .empty
    @State private var isSaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            ProfileHeading(title: L10n.nicknameSetupTitle, bodyText: L10n.nicknameSetupBody)
            VStack(alignment: .leading, spacing: 8) {
                NicknameField(text: $nickname, status: $status)
                Text(L10n.nicknameRules)
                    .font(Theme.Typography.Copy.label)
                    .foregroundStyle(Theme.subtleText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            PrimaryActionButton(title: L10n.nicknameDone, isEnabled: status.canSave && !isSaving) { save() }
        }
    }

    private func save() {
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await AccountService.shared.setNickname(nickname.trimmingCharacters(in: .whitespaces))
                onDone()
            } catch let error as AccountError {
                applyError(error, to: &status)
            } catch {}
        }
    }
}

/// Changing the nickname from Profil (Figma N1–N3): once per 24 hours,
/// with a confirmation, locked while waiting.
struct NicknameEditView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @ObservedObject private var account = AccountService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var nickname = ""
    @State private var status: NicknameField.Status = .unchanged
    @State private var isConfirming = false
    @State private var isSaving = false

    var body: some View {
        let me = account.me
        let nextChange = me?.nicknameNextChangeAt.flatMap { $0 > Date() ? $0 : nil }

        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                BackHeaderView(title: L10n.profileNickname, onBack: { dismiss() })
                VStack(alignment: .leading, spacing: 10) {
                    NicknameField(text: $nickname, status: $status, isLocked: nextChange != nil, currentNickname: me?.nickname)
                    if let nextChange {
                        let (day, time) = ProfileFormat.dayAndTime(nextChange)
                        Label(L10n.nicknameCooldown(day: day, time: time), systemImage: "clock")
                            .font(Theme.Typography.Copy.body)
                            .foregroundStyle(Theme.mutedText)
                    } else {
                        Text(L10n.nicknameRules)
                            .font(Theme.Typography.Copy.label)
                            .foregroundStyle(Theme.subtleText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                PrimaryActionButton(title: L10n.nicknameSave, isEnabled: nextChange == nil && status.canSave && !isSaving) {
                    isConfirming = true
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 36)
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { nickname = me?.nickname ?? "" }
        .confirmationDialog(L10n.nicknameConfirmTitle(nickname), isPresented: $isConfirming, titleVisibility: .visible) {
            Button(L10n.nicknameConfirmAction) { save() }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.nicknameConfirmBody)
        }
    }

    private func save() {
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await AccountService.shared.setNickname(nickname.trimmingCharacters(in: .whitespaces))
                dismiss()
            } catch let error as AccountError {
                if case .nicknameCooldown = error {
                    await AccountService.shared.refresh()
                } else {
                    applyError(error, to: &status)
                }
            } catch {}
        }
    }
}

@MainActor
private func applyError(_ error: AccountError, to status: inout NicknameField.Status) {
    switch error {
    case .nicknameTaken: status = .taken
    case .nicknameReserved: status = .reserved
    case .nicknameInvalid: status = .invalid
    default: ToastCenter.shared.show(.init(systemImage: "exclamationmark.circle", message: error.userMessage))
    }
}
