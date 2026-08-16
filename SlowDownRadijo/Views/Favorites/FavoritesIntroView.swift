import SwiftUI

/// Shown exactly once, right after the very first favorite is ever added
/// (see `HomeView`'s `hasSeenFavoritesIntro` flag) — explains where the
/// heart button just sent that track.
struct FavoritesIntroView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "heart.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(Theme.sunOrange)
                .frame(width: 76, height: 76)
                .background(Theme.sunOrange.opacity(0.12), in: Circle())
                .padding(.top, Theme.Spacing.lg)

            VStack(spacing: Theme.Spacing.sm) {
                Text(L10n.favoritesIntroTitle)
                    .font(Theme.Typography.Manrope.extraBold(size: 20, relativeTo: .title3))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text(L10n.favoritesIntroBody)
                    .font(Theme.Typography.Manrope.regular(size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.lavender)
                    .multilineTextAlignment(.center)
            }

            Button(L10n.favoritesIntroDismiss) {
                dismiss()
            }
            .font(Theme.Typography.Manrope.bold(size: 15, relativeTo: .subheadline))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.sunOrange, in: Capsule())
        }
        .padding(Theme.Spacing.xl)
        .background(Theme.background.ignoresSafeArea())
        .presentationDetents([.medium])
    }
}
