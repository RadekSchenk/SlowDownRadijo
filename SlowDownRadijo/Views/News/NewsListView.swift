import SwiftUI

/// Mirrors slowdownradijo.cz's own "Novinky" feed, read straight from its
/// public WordPress REST API — content stays managed entirely on the
/// website, nothing new to administer here.
struct NewsListView: View {
    @StateObject private var viewModel = NewsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                BackHeaderView(title: L10n.newsTitle, onBack: { dismiss() })
                content
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.loadIfNeeded() }
        .refreshable { await viewModel.refresh() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.xxl)
        case .failed:
            Text(L10n.newsLoadFailed)
                .font(Theme.Typography.Manrope.regular(size: 13, relativeTo: .footnote))
                .foregroundStyle(Theme.lavender)
        case .loaded(let posts):
            if posts.isEmpty {
                Text(L10n.newsEmpty)
                    .font(Theme.Typography.Manrope.regular(size: 13, relativeTo: .footnote))
                    .foregroundStyle(Theme.lavender)
            } else {
                LazyVStack(spacing: Theme.Spacing.md) {
                    ForEach(posts) { post in
                        NavigationLink {
                            NewsDetailView(post: post)
                        } label: {
                            NewsRowView(post: post)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct NewsRowView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    let post: NewsPost

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            RemoteArtworkView(url: post.featuredImageURL, cornerRadius: 12)
                .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 4) {
                Text(post.title)
                    .font(Theme.Typography.Manrope.bold(size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                Text(L10n.formattedDate(post.date))
                    .font(Theme.Typography.Manrope.regular(size: 12, relativeTo: .footnote))
                    .foregroundStyle(Theme.lavender)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}
