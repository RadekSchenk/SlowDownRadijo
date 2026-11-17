import SwiftUI

/// Signing in with an e‑mail code (Figma Profil E1–E3): the address, then
/// six digits. The same screen signs up a new listener.
struct EmailSignInView: View {
    var onSignedIn: () -> Void = {}

    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var request: AccountService.EmailCodeRequest?
    @State private var code = ""
    @State private var codeInvalid = false
    @State private var emailError: String?
    @State private var isWorking = false
    @State private var resendAt = Date()
    @FocusState private var focus: Field?

    private enum Field { case email, code }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                BackHeaderView(title: request == nil ? L10n.emailSignInTitle : L10n.emailCodeTitle) {
                    if request != nil {
                        request = nil
                        code = ""
                        codeInvalid = false
                    } else {
                        dismiss()
                    }
                }
                if let request {
                    codeStep(request)
                } else {
                    emailStep
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 36)
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { focus = .email }
    }

    // MARK: - E1

    private var emailStep: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Text(L10n.emailSignInBody)
                .font(Theme.Typography.Copy.body)
                .foregroundStyle(Theme.mutedText)

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.emailFieldLabel)
                    .font(Theme.Typography.Manrope.extraBold(size: 13, relativeTo: .footnote))
                    .foregroundStyle(Theme.mutedText)
                TextField(L10n.emailFieldPlaceholder, text: $email)
                    .font(Theme.Typography.Copy.reading)
                    .foregroundStyle(Theme.textPrimary)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.send)
                    .focused($focus, equals: .email)
                    .onSubmit(sendCode)
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                    .background(Theme.statsCardRaised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                if let emailError {
                    Text(emailError)
                        .font(Theme.Typography.Manrope.bold(size: 13, relativeTo: .footnote))
                        .foregroundStyle(Theme.liveRed)
                }
            }

            PrimaryActionButton(title: L10n.emailSendCode, isEnabled: !isWorking && !email.isEmpty, action: sendCode)

            Text(L10n.emailNewAccountNote)
                .font(Theme.Typography.Copy.label)
                .foregroundStyle(Theme.subtleText)
        }
    }

    private func sendCode() {
        let address = email.trimmingCharacters(in: .whitespaces)
        guard address.wholeMatch(of: /^[^@\s]+@[^@\s]+\.[^@\s]+$/) != nil else {
            emailError = L10n.emailInvalidAddress
            return
        }
        emailError = nil
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                request = try await AccountService.shared.sendEmailCode(to: address)
                resendAt = Date().addingTimeInterval(60)
                focus = .code
            } catch let error as AccountError {
                emailError = error.userMessage
            } catch {}
        }
    }

    // MARK: - E2 / E3

    private func codeStep(_ request: AccountService.EmailCodeRequest) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Text(L10n.emailCodeBody(request.email))
                .font(Theme.Typography.Copy.body)
                .foregroundStyle(Theme.mutedText)

            ZStack {
                // One real field under six boxes: paste and the keyboard's
                // "From Mail" suggestion fill all of it at once.
                TextField("", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($focus, equals: .code)
                    .opacity(0.01)
                    .onChange(of: code) { _, new in
                        let digits = String(new.filter(\.isNumber).prefix(6))
                        if digits != new { code = digits }
                        codeInvalid = false
                        if digits.count == 6 { verify(request) }
                    }
                HStack(spacing: 8) {
                    ForEach(0..<6, id: \.self) { index in
                        codeBox(index)
                    }
                }
                .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onTapGesture { focus = .code }

            if codeInvalid {
                Label(L10n.emailCodeInvalid, systemImage: "exclamationmark.circle")
                    .font(Theme.Typography.Manrope.bold(size: 13, relativeTo: .footnote))
                    .foregroundStyle(Theme.liveRed)
            }

            HStack(spacing: Theme.Spacing.md) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let left = Int(resendAt.timeIntervalSince(context.date).rounded(.up))
                    if left > 0 {
                        Text(L10n.emailResendIn(String(format: "0:%02d", left)))
                            .font(Theme.Typography.Copy.body)
                            .foregroundStyle(Theme.subtleText)
                            .monospacedDigit()
                    } else {
                        Button(L10n.emailResend, action: sendCode)
                            .font(Theme.Typography.Copy.link)
                            .foregroundStyle(Theme.mutedText)
                    }
                }
                Button(L10n.emailChange) {
                    self.request = nil
                    code = ""
                    codeInvalid = false
                    focus = .email
                }
                .font(Theme.Typography.Copy.link)
                .foregroundStyle(Theme.mutedText)
            }

            if isWorking {
                ProgressView().tint(.white)
            }
        }
    }

    private func codeBox(_ index: Int) -> some View {
        let digits = Array(code)
        let isCurrent = index == digits.count && focus == .code
        return Text(index < digits.count ? String(digits[index]) : "")
            .font(Theme.Typography.Manrope.extraBold(size: 24, relativeTo: .title2))
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(Theme.statsCardRaised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(codeInvalid ? Theme.liveRed : (isCurrent ? Theme.mutedText.opacity(0.8) : .clear), lineWidth: 1.5)
            )
    }

    private func verify(_ request: AccountService.EmailCodeRequest) {
        guard !isWorking else { return }
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await AccountService.shared.verifyEmailCode(code, for: request)
                onSignedIn()
            } catch AccountError.codeInvalid {
                codeInvalid = true
            } catch let error as AccountError {
                ToastCenter.shared.show(.init(systemImage: "exclamationmark.circle", message: error.userMessage))
            } catch {}
        }
    }
}
