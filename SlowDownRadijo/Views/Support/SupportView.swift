import SwiftUI

/// Styled after the home screen: 20pt page margin, 32pt between sections,
/// 24pt extraBold headings, `Theme.mutedText` subtitles, `Theme.liveRed` as
/// the only accent, and the platform picker as a divider-separated list
/// like the home screen's "Pořady".
///
/// All three support platforms list the same four benefits (verified
/// against slowdownradijo.cz/podpora/), so they're shown once in a shared
/// list rather than repeated under each platform.
struct SupportView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var safariURL: URL?
    @State private var isShowingSafari = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AppHeaderView()
                    .padding(.top, 40)

                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    intro
                    benefitsSection
                    platformsSection
                }
                .padding(.top, Theme.Spacing.sm)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .ignoresSafeArea(edges: .top)
        .background(Theme.background.ignoresSafeArea())
        .sheet(isPresented: $isShowingSafari) {
            if let safariURL {
                SafariView(url: safariURL)
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeading(L10n.tabSupport)
            Text(L10n.supportIntro)
                .font(Theme.Typography.Manrope.semibold(size: 16, relativeTo: .subheadline))
                .foregroundStyle(Theme.mutedText)
        }
    }

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            sectionHeading(L10n.supportBenefitsTitle)

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                ForEach(SupportOption.sharedBenefits, id: \.self) { benefit in
                    HStack(spacing: Theme.Spacing.md) {
                        // Same tinted-chip treatment as the home screen's ON-AIR badge.
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.liveRed)
                            .frame(width: 32, height: 32)
                            .background(Theme.liveRed.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                        Text(benefit)
                            .font(Theme.Typography.Manrope.bold(size: 16, relativeTo: .body))
                            .foregroundStyle(Theme.textPrimary)
                    }
                }
            }
        }
    }

    private var platformsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            sectionHeading(L10n.supportChooseTitle)

            VStack(spacing: 0) {
                ForEach(SupportOption.all) { option in
                    Rectangle()
                        .fill(Theme.divider)
                        .frame(height: 1)
                    SupportCardView(option: option) {
                        safariURL = option.url
                        isShowingSafari = true
                    }
                }
            }
        }
    }

    private func sectionHeading(_ title: String) -> some View {
        Text(title)
            .font(Theme.Typography.Manrope.extraBold(size: 24, relativeTo: .title2))
            .foregroundStyle(Theme.textPrimary)
    }
}
