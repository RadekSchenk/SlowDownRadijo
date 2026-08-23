import SwiftUI

/// Matches the flat "radio-flat-typo" typography/color scale used
/// throughout the rest of the app (see `HomeView`): 28pt
/// extraBold page title, 24pt extraBold section headers, `Theme.lavender`
/// for secondary text, `Theme.gold`/`Theme.sunOrange` for accents.
///
/// All three support platforms list the same four benefits (verified
/// against slowdownradijo.cz/podpora/), so they're shown once in a shared
/// list rather than repeated under each platform card — the previous
/// per-card benefit lists were pure duplication.
struct SupportView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var safariURL: URL?
    @State private var isShowingSafari = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                AppHeaderView()
                    // Matches the home screen's header offset exactly (see
                    // `HomeView.heroSection`) — fixed 40pt from the true
                    // top edge, not the system safe-area inset.
                    .padding(.top, 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.tabSupport)
                        .font(Theme.Typography.Manrope.extraBold(size: 28, relativeTo: .title))
                        .foregroundStyle(Theme.textPrimary)
                    Text(L10n.supportIntro)
                        .font(Theme.Typography.Manrope.regular(size: 13, relativeTo: .footnote))
                        .foregroundStyle(Theme.lavender)
                }

                benefitsSection

                platformsSection
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.md)
        }
        .ignoresSafeArea(edges: .top)
        .background(Theme.background.ignoresSafeArea())
        .sheet(isPresented: $isShowingSafari) {
            if let safariURL {
                SafariView(url: safariURL)
            }
        }
    }

    /// Deliberately not boxed in an outlined card like the platform picker
    /// below — this is the "sell" moment, so it gets more room to breathe:
    /// a bigger heading, bold primary-color text instead of muted
    /// secondary, and a colored icon chip per benefit rather than a small
    /// inline checkmark.
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Text(L10n.supportBenefitsTitle)
                .font(Theme.Typography.Manrope.extraBold(size: 24, relativeTo: .title2))
                .foregroundStyle(Theme.textPrimary)

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                ForEach(SupportOption.sharedBenefits, id: \.self) { benefit in
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.gold)
                            .frame(width: 34, height: 34)
                            .background(Theme.gold.opacity(0.15), in: Circle())

                        Text(benefit)
                            .font(Theme.Typography.Manrope.semibold(size: 17, relativeTo: .body))
                            .foregroundStyle(Theme.textPrimary)
                    }
                }
            }
        }
    }

    private var platformsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Matches `supportBenefitsTitle` above — both are page-level
            // section headers, so they share the same 24pt extraBold scale
            // rather than this one being a step smaller.
            Text(L10n.supportChooseTitle)
                .font(Theme.Typography.Manrope.extraBold(size: 24, relativeTo: .title2))
                .foregroundStyle(Theme.textPrimary)

            ForEach(SupportOption.all) { option in
                SupportCardView(option: option) {
                    safariURL = option.url
                    isShowingSafari = true
                }
            }
        }
    }
}
