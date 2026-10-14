import SwiftUI

/// The gentle ask for anonymous usage analytics on the home screen: a card
/// in the flow of the page, never a blocking dialog. Shows from the third
/// launch until the listener answers either way (`Analytics`); the same
/// choice lives in Settings afterwards.
struct AnalyticsConsentCard: View {
    @ObservedObject private var loc = LocalizationManager.shared
    let onAnswer: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.liveRed)
                    .frame(width: 32, height: 32)
                    .background(Theme.liveRed.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.analyticsConsentTitle)
                        .font(Theme.Typography.Manrope.extraBold(size: 16, relativeTo: .headline))
                        .foregroundStyle(Theme.textPrimary)
                    Text(L10n.analyticsConsentBody)
                        .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .subheadline))
                        .foregroundStyle(Theme.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: Theme.Spacing.sm) {
                answerButton(L10n.analyticsConsentDecline, isPrimary: false) { onAnswer(false) }
                answerButton(L10n.analyticsConsentAllow, isPrimary: true) { onAnswer(true) }
            }
        }
        .padding(16)
        .background(Theme.statsCardRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func answerButton(_ title: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Typography.Manrope.extraBold(size: 15, relativeTo: .subheadline))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    isPrimary ? Theme.liveRed : Theme.hairline(0.08),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
        }
        .buttonStyle(.plain)
    }
}
