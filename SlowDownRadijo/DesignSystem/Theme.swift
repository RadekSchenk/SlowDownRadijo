import SwiftUI
import UIKit

/// Visual identity derived from slowdownradijo.cz (logo + theme CSS).
///
/// The website itself mixes two different purples (a vivid magenta-purple
/// gradient `#7d08d7 → #570397` used for buttons/links, and a flatter
/// indigo-purple `#544495` used in the logo mark) plus a warm
/// yellow→orange→red gradient in the logo's "sun" icon. For the app we
/// unify this into one coherent system rather than reproducing the web's
/// inconsistency: the warm sunburst gradient becomes the single primary
/// accent (play button, active states, CTAs), and the indigo brand purple
/// is used sparingly as a secondary tint. Backgrounds follow the site's
/// dark theme (`#101010` / `#111618`).
enum Theme {
    // Backgrounds — the app is dark-only (there is no light mode and no
    // appearance toggle; `UIUserInterfaceStyle` is pinned to Dark too).
    // The page background matches the "Co hrálo" card redesign's frame
    // background (`#120e25`, updated 2026-08-23 from the earlier `#1a1535`) —
    // reused as the one background across the whole app rather than just
    // that one screen.
    static let background = Color(hex: 0x120E25)
    static let surface = Color(hex: 0x1A1A1E)
    static let surfaceElevated = Color(hex: 0x222226)
    /// The tab bar deliberately did **not** follow `background`'s
    /// 2026-08-23 update (`#1a1535` → `#120e25`) — Figma's `bottom-nav`
    /// spec still uses the old `#1a1535` for a subtle visual separation
    /// from the page content above it. Light-mode value matches
    /// `background`'s own light value, unchanged.
    static let tabBarBackground = Color(hex: 0x1A1535)
    /// Home screen's secondary text (`#b8afdc`) — "Pořad končí za…",
    /// progress times, disclosure links, subtitles. Brighter than `lavender`.
    static let mutedText = Color(hex: 0xB8AFDC)
    /// Quieter tertiary text (`#a699b8`) — names/details under a row title.
    static let subtleText = Color(hex: 0xA699B8)
    /// Solid list-row divider (`#332b4d`).
    static let divider = Color(hex: 0x332B4D)
    /// Statistiky cards (`#1a1535` in Figma).
    static let statsCard = Color(hex: 0x1A1535)
    /// The smaller metric tiles on the home screen's stats block (`#241c3a`).
    static let statsCardRaised = Color(hex: 0x241C3A)
    /// Non-peak bars of the weekly chart (`#665781`).
    static let statsBarMuted = Color(hex: 0x665781)
    /// The unselected tab label/icon color stayed at the old `lavender`
    /// dark value (`#b8afdc`) even after `lavender` itself moved to `#8f89a9`.
    static let tabBarUnselected = mutedText

    // Brand
    /// Matches the Figma splash screen's background exactly (`#433785`) —
    /// slightly deeper than the logo mark's own flat purple.
    static let brandPurple = Color(hex: 0x433785)
    static let sunYellow = Color(hex: 0xFAB817)
    /// Updated to the exact flat-redesign value (`#e8652b`, was `#ed8235`) —
    /// close enough to be the "same" orange, but this is now the source of
    /// truth for the single-color flat accent (play button, ON-AIR badge,
    /// progress fill).
    static let sunOrange = Color(hex: 0xE8652B)
    static let sunRed = Color(hex: 0xE04A4F)
    /// The action color (`#db304e`): play button, progress fill, selected
    /// tab, and every primary control on Vzkaz and Podpora. `sunOrange` is
    /// legacy — only screens not yet restyled to the home screen still use it.
    static let liveRed = Color(hex: 0xDB304E)
    /// Flat, muted fill for the *unplayed* portion of `NowPlayingWaveform`'s
    /// bars (`#2a263b`) — distinct from `surfaceElevated`, which reads too
    /// light against this specific waveform context.
    static let waveformMuted = Color(hex: 0x2A263B)
    /// The *unplayed* part of the home equalizer and the progress track under
    /// it (`#b8afdc`) — bright enough to show that something is there. The
    /// Vzkaz recording waveform still uses the darker `waveformMuted`.
    static let equalizerUnplayed = Color(hex: 0xB8AFDC)

    static let accentGradient = LinearGradient(
        colors: [sunYellow, sunOrange, sunRed],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Same three stops as `accentGradient`, rotated vertical — red grounded
    /// at the bottom rising to yellow at the top.
    static let accentGradientVertical = LinearGradient(
        colors: [sunYellow, sunOrange, sunRed],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Muted lavender used for secondary text in the flat redesign — a
    /// tinted alternative to a plain white-opacity gray, giving text a
    /// warmer, more "branded" look than generic gray would. Matches the
    /// "Co hrálo" card redesign's muted text (`#8f89a9`, updated 2026-08-23
    /// from the brighter `#b8afdc`).
    static let lavender = Color(hex: 0x8F89A9)
    /// Warm gold used for small "not the main accent" highlights — the
    /// "PRÁVĚ HRAJE" kicker label and the Spotify CTA. Deliberately not
    /// Spotify's own green: the redesign keeps every accent in-house rather
    /// than borrowing a third party's brand color.
    static let gold = Color(hex: 0xD4A24C)
    /// A legible accent purple for text/icons/borders — distinct from
    /// `brandPurple`, which is a *fixed* color deliberately kept constant
    /// for the splash screen background and decorative glows, where it's
    /// never read as foreground text against a variable background. This
    /// one is a lighter purple that stays readable against
    /// `surface`/`background`. No longer used by the "Najít na Spotify" pill,
    /// which reverted to `spotifyGreen` as of the 2026-08-23 redesign —
    /// kept in case another screen needs a legible purple.
    static let purpleAccent = Color(hex: 0xA78BFA)

    /// Spotify's brand green, used by the "Najít na Spotify" action chip
    /// (`TrackDetailsRow`) — a filled, 10%-opacity tint chip rather than
    /// legible-on-dark text, so the brand color reads fine without the
    /// legibility problem the earlier `purpleAccent` swap was solving.
    /// Updated 2026-08-23 to the "Co hrálo" redesign's exact value
    /// (`#00ca47`, was `#1ed760`).
    static let spotifyGreen = Color(hex: 0x00CA47)

    // Text
    static let textPrimary = Color(hex: 0xFFFFFF)
    static let textSecondary = Color(hex: 0xFFFFFF, alpha: 0.6)
    static let textTertiary = Color(hex: 0xFFFFFF, alpha: 0.4)

    // Status
    static let statusError = Color(hex: 0xE04A4F)
    static let statusLive = Color(hex: 0xFAB817)

    /// Faint hairline overlay — card borders, unfilled progress tracks,
    /// translucent pill backgrounds: white at the given opacity.
    static func hairline(_ opacity: Double) -> Color {
        Color.white.opacity(opacity)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum Radius {
        static let card: CGFloat = 20
        static let button: CGFloat = 16
        static let pill: CGFloat = 100
    }

    enum Typography {
        /// Manrope is used for every text in the app (the user's own
        /// explicit choice, overriding both the Figma spec's Outfit/Inter
        /// and a suggested SF Pro fallback). Bundled as static TTFs under
        /// `Resources/Fonts`; registered via `UIAppFonts` in Info.plist.
        /// `relativeTo:` keeps it Dynamic-Type-aware despite being a custom
        /// (non-system) font.
        /// Note: the bundled TTFs report their PostScript name as
        /// "ManropeExtraLight-*" — a labeling quirk in Google Fonts' static
        /// instances generated from the variable font (the outlines are the
        /// correct weight; only the internal name is off). Verified by
        /// rendering each file — Regular/Medium/SemiBold/Bold are visually
        /// distinct — so this isn't a case of four copies of one weight.
        enum Manrope {
            /// Static wght-300 instance cut from Google Fonts' `Manrope[wght].ttf`
            /// (same naming scheme as the other weights) — for Figma's big
            /// thin numerals: programme times, day-picker dates.
            static func light(size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
                .custom("ManropeExtraLight-Light", size: size, relativeTo: style)
            }
            static func regular(size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
                .custom("ManropeExtraLight-Regular", size: size, relativeTo: style)
            }
            static func medium(size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
                .custom("ManropeExtraLight-Medium", size: size, relativeTo: style)
            }
            static func semibold(size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
                .custom("ManropeExtraLight-SemiBold", size: size, relativeTo: style)
            }
            static func bold(size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
                .custom("ManropeExtraLight-Bold", size: size, relativeTo: style)
            }
            static func extraBold(size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
                .custom("ManropeExtraLight-ExtraBold", size: size, relativeTo: style)
            }

            /// UIKit bridge for the few chrome surfaces that predate
            /// SwiftUI's `Text` and take an attributed-string `UIFont`
            /// instead — `UITabBarAppearance`/`UINavigationBarAppearance`
            /// (see `RootTabView.configureTabBarAppearance`). `weight` must
            /// match one of the PostScript names above (Regular/Medium/
            /// SemiBold/Bold/ExtraBold). Falls back to the system font so
            /// this chrome never silently goes unstyled if the TTF can't be
            /// found by name.
            static func uiFont(weight: String, size: CGFloat) -> UIFont {
                UIFont(name: "ManropeExtraLight-\(weight)", size: size) ?? .systemFont(ofSize: size, weight: .semibold)
            }
        }
    }
}

extension View {
    /// Matches a Figma fixed line height (e.g. 30pt text on a 38pt line) for
    /// Manrope, whose natural line box is 1.366× the font size: trims or adds
    /// the difference evenly above and below, the way CSS half-leading does.
    func manropeLineHeight(_ lineHeight: CGFloat, fontSize: CGFloat) -> some View {
        padding(.vertical, (lineHeight - fontSize * 1.366) / 2)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
