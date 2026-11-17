import AuthenticationServices
import SwiftUI

/// "Pokračovat s Apple / s Google / e‑mailem" — Figma Profil M2 and the
/// chat's sign-in sheet. Apple's is the system button (Apple's own text and
/// logo, as App Review expects); Google's follows Google's dark button
/// (logo unchanged, #131314 with a #8E918F border); e‑mail is ours.
///
/// Sign-in failures are shown as a toast here; success updates
/// `AccountService.state`, which the screens follow.
struct SignInButtons: View {
    let onEmail: () -> Void

    @ObservedObject private var loc = LocalizationManager.shared
    @State private var appleNonce = AccountService.makeAppleNonce()
    @State private var isWorking = false

    static let height: CGFloat = 48

    var body: some View {
        VStack(spacing: 10) {
            SignInWithAppleButton(.continue) { request in
                appleNonce = AccountService.makeAppleNonce()
                request.requestedScopes = [.email]
                request.nonce = appleNonce.hashed
            } onCompletion: { result in
                let raw = appleNonce.raw
                run(provider: "Apple") {
                    try await AccountService.shared.signInWithApple(result, rawNonce: raw)
                }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: Self.height)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Button {
                run(provider: "Google") { try await AccountService.shared.signInWithGoogle() }
            } label: {
                HStack(spacing: 10) {
                    Image("GoogleLogo")
                        .resizable()
                        .frame(width: 18, height: 18)
                    Text(L10n.signInGoogle)
                }
                .font(Theme.Typography.Copy.button)
                .foregroundStyle(Color(hex: 0xE3E3E3))
                .frame(maxWidth: .infinity)
                .frame(height: Self.height)
                .background(Color(hex: 0x131314), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color(hex: 0x8E918F), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Button(action: onEmail) {
                HStack(spacing: 10) {
                    Image(systemName: "envelope")
                    Text(L10n.signInEmail)
                }
                .font(Theme.Typography.Copy.button)
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: Self.height)
                .background(Theme.hairline(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .disabled(isWorking)
        .opacity(isWorking ? 0.5 : 1)
        .overlay {
            if isWorking { ProgressView().tint(.white) }
        }
    }

    private func run(provider: String, _ work: @escaping () async throws -> Void) {
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await work()
            } catch let error as AccountError {
                switch error {
                case .cancelled:
                    break
                case .providerUnavailable, .offline:
                    ToastCenter.shared.show(.init(systemImage: "exclamationmark.circle", message: error.userMessage))
                default:
                    ToastCenter.shared.show(.init(systemImage: "exclamationmark.circle", message: L10n.signInFailed(provider)))
                }
            } catch {
                ToastCenter.shared.show(.init(systemImage: "exclamationmark.circle", message: L10n.signInFailed(provider)))
            }
        }
    }
}
