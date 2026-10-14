import SwiftUI

/// Mirrors slowdownradijo.cz's own "Novinky" feed, read straight from its
/// public WordPress REST API — content stays managed entirely on the
/// website, nothing new to administer here. Also home to the "new post"
/// notification toggle, which used to be its own menu item.
struct NewsListView: View {
    @StateObject private var viewModel = NewsViewModel()
    @AppStorage("newsNotificationsEnabled") private var newsNotificationsEnabled = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                BackHeaderView(title: L10n.newsTitle, onBack: { dismiss() })

                VStack(spacing: 0) {
                    ListDivider()
                    notificationToggleRow
                    ListDivider()
                    content
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.loadIfNeeded() }
        .refreshable { await viewModel.refresh() }
        .onChange(of: newsNotificationsEnabled) { _, isEnabled in
            guard isEnabled else { return }
            Task { await NewsNotificationManager.requestAuthorizationIfNeeded() }
        }
    }

    private var notificationToggleRow: some View {
        ListRow(title: L10n.notificationsNewPostTitle, subtitle: L10n.notificationsNewPostDescription) {
            ListRowIcon(systemName: "bell.fill")
        } trailing: {
            Toggle("", isOn: $newsNotificationsEnabled)
                .labelsHidden()
                .tint(Theme.liveRed)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.xxl)
        case .failed:
            statusText(L10n.newsLoadFailed)
        case .loaded(let posts):
            if posts.isEmpty {
                statusText(L10n.newsEmpty)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                        if index > 0 {
                            ListDivider()
                        }
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

    private func statusText(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typography.Manrope.semibold(size: 16, relativeTo: .subheadline))
            .foregroundStyle(Theme.mutedText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 20)
    }
}

/// A "Pořady"-style row: artwork, extraBold title, subtle date line.
private struct NewsRowView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    let post: NewsPost

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            RemoteArtworkView(url: post.featuredImageURL, cornerRadius: 2)
                .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 4) {
                Text(post.title)
                    .font(Theme.Typography.Manrope.extraBold(size: 18, relativeTo: .headline))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(3)
                Text(L10n.formattedDate(post.date))
                    .font(Theme.Typography.Manrope.regular(size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.subtleText)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 20)
        .contentShape(Rectangle())
    }
}
