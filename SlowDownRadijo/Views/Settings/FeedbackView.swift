import SwiftUI

/// Pushed from the hamburger menu, always last — an in-app feedback form
/// that relays to `jsem@radekschenk.cz` via the `send-feedback` Edge
/// Function. Styled like the Vzkaz tab (shared action buttons, muted
/// subtitle, header-pill surfaces).
struct FeedbackView: View {
    @StateObject private var feedbackViewModel = FeedbackViewModel()
    @Environment(\.dismiss) private var dismiss

    private static let successGreen = Color(hex: 0x28C840)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                BackHeaderView(title: L10n.settingsFeedbackTitle, onBack: { dismiss() })

                Text(L10n.settingsFeedbackIntro)
                    .font(Theme.Typography.Manrope.semibold(size: 16, relativeTo: .subheadline))
                    .foregroundStyle(Theme.mutedText)

                switch feedbackViewModel.state {
                case .idle, .sending, .failed:
                    feedbackForm
                    if feedbackViewModel.state == .failed {
                        Text(L10n.settingsFeedbackFailed)
                            .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .footnote))
                            .foregroundStyle(Theme.statusError)
                    }
                case .sent:
                    sentConfirmation
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var feedbackForm: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            ZStack(alignment: .topLeading) {
                if feedbackViewModel.message.isEmpty {
                    Text(L10n.settingsFeedbackPlaceholder)
                        .font(Theme.Typography.Manrope.regular(size: 16, relativeTo: .body))
                        .foregroundStyle(Theme.subtleText)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $feedbackViewModel.message)
                    .font(Theme.Typography.Manrope.regular(size: 16, relativeTo: .body))
                    .foregroundStyle(Theme.textPrimary)
                    .tint(Theme.liveRed)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 160)
                    .disabled(feedbackViewModel.state == .sending)
            }
            .background(Theme.hairline(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            PrimaryActionButton(
                title: feedbackViewModel.state == .sending ? L10n.settingsFeedbackSending : L10n.settingsFeedbackSend,
                systemImage: "paperplane.fill",
                isEnabled: feedbackViewModel.canSubmit,
                action: feedbackViewModel.submit
            )
        }
    }

    private var sentConfirmation: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            // Same badge as the Vzkaz tab's "ODESLÁNO".
            HStack(spacing: 8) {
                Circle()
                    .fill(Self.successGreen)
                    .frame(width: 10, height: 10)
                Text(L10n.sentBadge)
                    .font(Theme.Typography.Manrope.extraBold(size: 14))
                    .foregroundStyle(Self.successGreen)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Self.successGreen.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(L10n.settingsFeedbackSent)
                .font(Theme.Typography.Manrope.bold(size: 16, relativeTo: .body))
                .foregroundStyle(Theme.textPrimary)

            SecondaryActionButton(title: L10n.settingsFeedbackSendAnother) {
                feedbackViewModel.reset()
            }
        }
    }
}
