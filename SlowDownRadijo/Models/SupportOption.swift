import Foundation

struct SupportOption: Identifiable {
    let id: String
    let name: String
    /// Just the currency amount (e.g. "8 €", "170 Kč") — the "/month"-style
    /// suffix is appended via `price` from `L10n.perMonth` so it localizes.
    let amount: String
    let url: URL
    /// Name of a theme-adaptive imageset in Assets.xcassets (light/dark
    /// appearance variants of the platform's own brand mark), not an SF
    /// Symbol — real logos read more trustworthy on a support/payment card.
    let logoAssetName: String

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
            logoAssetName: "SupportHerohero"
        ),
        SupportOption(
            id: "patreon",
            name: "Patreon",
            amount: "170 Kč",
            url: URL(string: "https://www.patreon.com/c/SLOWDOWNRADIJO")!,
            logoAssetName: "SupportPatreon"
        ),
        SupportOption(
            id: "forendors",
            name: "Forendors",
            amount: "160 Kč",
            url: URL(string: "https://www.forendors.cz/slowdownradijo")!,
            logoAssetName: "SupportForendors"
        )
    ]
}
