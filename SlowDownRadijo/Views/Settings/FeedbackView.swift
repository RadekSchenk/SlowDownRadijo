import SwiftUI

/// Pushed from the hamburger menu, always last — an in-app feedback form
/// that relays to `jsem@radekschenk.cz` via the `send-feedback` Edge
/// Function. Used to live inside `SettingsView`; split out into its own
/// menu item.
struct FeedbackView: View {
    @StateObject private var feedbackViewModel = FeedbackViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                BackHeaderView(title: L10n.settingsFeedbackTitle, onBack: { dismiss() })

                Text(L10n.settingsFeedbackIntro)
                    .font(Theme.Typography.Manrope.regular(size: 13, relativeTo: .footnote))
                    .foregroundStyle(Theme.lavender)

                switch feedbackViewModel.state {
                case .idle, .sending, .failed:
                    feedbackForm
                    if feedbackViewModel.state == .failed {
                        Text(L10n.settingsFeedbackFailed)
                            .font(Theme.Typography.Manrope.regular(size: 12, relativeTo: .footnote))
                            .foregroundStyle(Theme.statusError)
                    }
                case .sent:
                    sentConfirmation
                }
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var feedbackForm: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            ZStack(alignment: .topLeading) {
                if feedbackViewModel.message.isEmpty {
                    Text(L10n.settingsFeedbackPlaceholder)
                        .font(Theme.Typography.Manrope.regular(size: 15, relativeTo: .body))
                        .foregroundStyle(Theme.lavender)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $feedbackViewModel.message)
                    .font(Theme.Typography.Manrope.regular(size: 15, relativeTo: .body))
                    .foregroundStyle(Theme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 160)
                    .disabled(feedbackViewModel.state == .sending)
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Theme.hairline(0.1), lineWidth: 1)
                    .allowsHitTesting(false)
            )

            Button(action: feedbackViewModel.submit) {
                Text(feedbackViewModel.state == .sending ? L10n.settingsFeedbackSending : L10n.settingsFeedbackSend)
                    .font(Theme.Typography.Manrope.bold(size: 15, relativeTo: .subheadline))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(
                        feedbackViewModel.canSubmit ? Theme.sunOrange : Theme.sunOrange.opacity(0.4),
                        in: Capsule()
                    )
            }
            .buttonStyle(.plain)
            .disabled(!feedbackViewModel.canSubmit)
        }
    }

    private var sentConfirmation: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color(hex: 0x28C840))
                Text(L10n.settingsFeedbackSent)
                    .font(Theme.Typography.Manrope.semibold(size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Theme.textPrimary)
            }

            Button(L10n.settingsFeedbackSendAnother) {
                feedbackViewModel.reset()
            }
            .font(Theme.Typography.Manrope.bold(size: 14, relativeTo: .subheadline))
            .foregroundStyle(Theme.sunOrange)
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.hairline(0.1), lineWidth: 1)
                .allowsHitTesting(false)
        )
    }
}
