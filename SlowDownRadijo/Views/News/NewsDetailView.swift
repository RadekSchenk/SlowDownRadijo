import SwiftUI

/// A single "Novinky" article — deliberately not a mirror of the site's
/// own layout (no categories, likes, ratings, sharing, comments; those
/// are WordPress-theme chrome). Just the publish date, title, and content
/// in original order, parsed by `NewsContentParser`.
struct NewsDetailView: View {
    let post: NewsPost
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var safariURL: URL?
    @State private var isShowingSafari = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                BackHeaderView(title: L10n.newsTitle, onBack: { dismiss() })

                if let imageURL = post.featuredImageURL {
                    RemoteArtworkView(url: imageURL, cornerRadius: Theme.Radius.card)
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.formattedDate(post.date))
                        .font(Theme.Typography.Manrope.semibold(size: 12, relativeTo: .footnote))
                        .foregroundStyle(Theme.gold)
                    Text(post.title)
                        .font(Theme.Typography.Manrope.extraBold(size: 22, relativeTo: .title2))
                        .foregroundStyle(Theme.textPrimary)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    ForEach(post.contentBlocks) { block in
                        blockView(block)
                    }
                }
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isShowingSafari) {
            if let safariURL {
                SafariView(url: safariURL)
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: NewsContentBlock) -> some View {
        switch block {
        case .paragraph(let text):
            Text(text)
                .font(Theme.Typography.Manrope.regular(size: 16, relativeTo: .body))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        case .image(let url):
            RemoteArtworkView(url: url, cornerRadius: Theme.Radius.card)
                .frame(maxWidth: .infinity)
                .frame(height: 200)
        case .videoEmbed(let url):
            Button {
                safariURL = url
                isShowingSafari = true
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 20))
                    Text(L10n.newsWatchVideo)
                        .font(Theme.Typography.Manrope.bold(size: 14, relativeTo: .subheadline))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.sunOrange, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}
