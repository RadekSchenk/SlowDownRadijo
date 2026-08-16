import Foundation

struct SupportOption: Identifiable {
    let id: String
    let name: String
    /// Just the currency amount (e.g. "8 €", "170 Kč") — the "/month"-style
    /// suffix is appended via `price` from `L10n.perMonth` so it localizes.
    let amount: String
    let url: URL
    let symbolName: String

    var price: String { "\(amount)/\(L10n.perMonth)" }

    /// Verified against https://slowdownradijo.cz/podpora/ — all three
    /// platforms list the same four benefits, so this is shown once above
    /// the platform picker (see `SupportView`) instead of repeating under
    /// every card.
    static var sharedBenefits: [String] {
        [L10n.benefitRecordings, L10n.benefitBehindTheScenes, L10n.benefitContests, L10n.benefitMerchDiscount]
    }

    static let all: [SupportOption] = [
        SupportOption(
            id: "herohero",
            name: "Herohero",
            amount: "8 €",
            url: URL(string: "https://herohero.co/slowdownradijo")!,
            symbolName: "star.circle.fill"
        ),
        SupportOption(
            id: "patreon",
            name: "Patreon",
            amount: "170 Kč",
            url: URL(string: "https://www.patreon.com/c/SLOWDOWNRADIJO")!,
            symbolName: "heart.circle.fill"
        ),
        SupportOption(
            id: "forendors",
            name: "Forendors",
            amount: "160 Kč",
            url: URL(string: "https://www.forendors.cz/slowdownradijo")!,
            symbolName: "gift.circle.fill"
        )
    ]
}
