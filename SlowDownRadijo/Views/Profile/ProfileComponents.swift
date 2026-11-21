import SwiftUI

/// A row of the Profil lists: title, optional value, optional chevron —
/// the same 20pt rhythm as `ListRow`, with a red title for destructive
/// actions ("Smazat účet").
struct ProfileRow: View {
    let title: String
    var value: String? = nil
    var showsChevron = true
    var isDestructive = false

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(title)
                .font(Theme.Typography.Heading.item)
                .foregroundStyle(isDestructive ? Theme.liveRed : Theme.textPrimary)
            Spacer(minLength: Theme.Spacing.sm)
            if let value {
                Text(value)
                    .font(Theme.Typography.Copy.body)
                    .foregroundStyle(Theme.mutedText)
                    .lineLimit(1)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.subtleText)
            }
        }
        .padding(.vertical, 18)
        .contentShape(Rectangle())
    }
}

/// A section of the Profil page: 19pt heading, then rows split by dividers.
struct ProfileSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Theme.Typography.Heading.section)
                .foregroundStyle(Theme.textPrimary)
            VStack(spacing: 0) {
                content
            }
        }
    }
}

/// Page title + intro text, as on the other tabs.
struct ProfileHeading: View {
    let title: String
    var bodyText: String? = nil
    /// `Heading.page` for a screen's own title, `Heading.hero` under "Profil".
    var titleFont: Font = Theme.Typography.Heading.page

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(titleFont)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let bodyText {
                Text(bodyText)
                    .font(Theme.Typography.Copy.body)
                    .foregroundStyle(Theme.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// "Psaní do chatu máš pozastavené do zítra 8:04" — Figma Profil M4.
struct MutedBanner: View {
    let mutedUntil: Date?
    let blocked: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "speaker.slash")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.mutedText)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typography.Manrope.extraBold(size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.textPrimary)
                Text(L10n.mutedBannerBody)
                    .font(Theme.Typography.Copy.label)
                    .foregroundStyle(Theme.mutedText)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Theme.statsCardRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
    }

    private var title: String {
        if blocked || mutedUntil == nil { return L10n.blockedBanner }
        let (day, time) = ProfileFormat.dayAndTime(mutedUntil!)
        return L10n.mutedBanner(day: day, time: time)
    }
}

enum ProfileFormat {
    /// ("dnes" / "zítra" / "20. 11.", "8:04") for a moment within a few days.
    static func dayAndTime(_ date: Date, now: Date = Date()) -> (day: String, time: String) {
        let calendar = Calendar.current
        let time = date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute(.twoDigits))
        if calendar.isDate(date, inSameDayAs: now) { return (L10n.dayToday, time) }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return (L10n.dayTomorrow, time)
        }
        let day = "\(calendar.component(.day, from: date)). \(calendar.component(.month, from: date)). "
        return (day.trimmingCharacters(in: .whitespaces), time)
    }

    /// "18. 11. 2026"
    static func date(_ date: Date) -> String {
        let calendar = Calendar.current
        return "\(calendar.component(.day, from: date)). \(calendar.component(.month, from: date)). \(calendar.component(.year, from: date))"
    }

    static func methodName(_ method: AccountService.SignInMethod?) -> String {
        switch method {
        case .apple: return "Apple"
        case .google: return "Google"
        case .email, .none: return L10n.signInMethodEmail
        }
    }
}

/// Pravidla chatu — Figma Profil S2.
struct ChatRulesView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                BackHeaderView(title: L10n.chatRulesTitle, onBack: { dismiss() })
                Text(L10n.chatRulesIntro)
                    .font(Theme.Typography.Copy.body)
                    .foregroundStyle(Theme.mutedText)
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array([L10n.chatRule1, L10n.chatRule2, L10n.chatRule3, L10n.chatRule4, L10n.chatRule5].enumerated()), id: \.offset) { index, rule in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("\(index + 1)")
                                .font(Theme.Typography.Manrope.extraBold(size: 16, relativeTo: .body))
                                .foregroundStyle(Theme.liveRed)
                            Text(rule)
                                .font(Theme.Typography.Copy.reading)
                                .foregroundStyle(Theme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 36)
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// Skrytí uživatelé — Figma Profil S1.
struct HiddenUsersView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var users: [AccountService.HiddenUser] = []
    @State private var isLoaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                BackHeaderView(title: L10n.profileHiddenUsers, onBack: { dismiss() })
                Text(L10n.hiddenUsersBody)
                    .font(Theme.Typography.Copy.body)
                    .foregroundStyle(Theme.mutedText)
                if isLoaded && users.isEmpty {
                    Text(L10n.hiddenUsersEmpty)
                        .font(Theme.Typography.Copy.reading)
                        .foregroundStyle(Theme.subtleText)
                } else {
                    VStack(spacing: 0) {
                        ForEach(users) { user in
                            ListDivider()
                            HStack {
                                Text(user.name ?? L10n.deletedAccount)
                                    .font(Theme.Typography.Heading.item)
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Button(L10n.hiddenUsersShow) { unhide(user) }
                                    .font(Theme.Typography.Copy.link)
                                    .foregroundStyle(Theme.liveRed)
                            }
                            .padding(.vertical, 18)
                        }
                        if !users.isEmpty { ListDivider() }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 36)
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
    }

    private func load() async {
        users = (try? await AccountService.shared.hiddenUsers()) ?? []
        isLoaded = true
    }

    private func unhide(_ user: AccountService.HiddenUser) {
        Task {
            do {
                try await AccountService.shared.unhide(user.userID)
                users.removeAll { $0.id == user.id }
            } catch let error as AccountError {
                ToastCenter.shared.show(.init(systemImage: "exclamationmark.circle", message: error.userMessage))
            } catch {}
        }
    }
}
