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
    // Backgrounds — dark is the site's (and this app's) primary look, but
    // every color adapts so the app still works correctly in Light Mode
    // instead of forcing one appearance and ignoring the system setting.
    // Dark value matches the "Co hrálo" card redesign's frame background
    // (`#120e25`, updated 2026-08-23 from the earlier `#1a1535`) — reused
    // as the one dark-mode background across the whole app rather than
    // just that one screen.
    static let background = Color.adaptive(light: 0xF5F5F7, dark: 0x120E25)
    static let surface = Color.adaptive(light: 0xFFFFFF, dark: 0x1A1A1E)
    static let surfaceElevated = Color.adaptive(light: 0xEDEDF2, dark: 0x222226)

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
    /// A second, distinct red — "live"/now-playing accent introduced by the
    /// 2026-08-23 home-screen hero redesign (`#db304e`). Deliberately
    /// scoped to now-playing-card surfaces only (`PlayButton`,
    /// `ShowProgressBar`, `NowPlayingEqualizer`, `NowPlayingWaveform`) —
    /// `sunOrange` remains the app-wide accent everywhere else (tab bar,
    /// Settings, Vzkaz, Program, Support), so don't reach for this outside
    /// the now-playing card without the design calling for it.
    static let liveRed = Color(hex: 0xDB304E)
    /// Flat, muted fill for the *unplayed* portion of `NowPlayingWaveform`'s
    /// bars (`#2a263b`) — distinct from `surfaceElevated`, which is
    /// adaptive and reads too light against this specific dark waveform
    /// context.
    static let waveformMuted = Color(hex: 0x2A263B)

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

    /// Yellow-to-`liveRed` gradient for each *elapsed* bar in
    /// `NowPlayingWaveform` — applied per-bar (not as one shared mask
    /// across the whole shape), matching the Figma source's own per-bar
    /// `bg-gradient-to-b`.
    static let liveWaveformGradient = LinearGradient(
        colors: [sunYellow, liveRed],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Muted lavender used for secondary text in the flat redesign — a
    /// tinted alternative to a plain white-opacity gray, giving text a
    /// warmer, more "branded" look than generic gray would. Adaptive: the
    /// original light purple-gray only reads against the dark background;
    /// Light Mode gets a deeper plum instead of going near-invisible. Dark
    /// value matches the "Co hrálo" card redesign's muted text (`#8f89a9`,
    /// updated 2026-08-23 from the brighter `#b8afdc`).
    static let lavender = Color.adaptive(light: 0x5C4F8A, dark: 0x8F89A9)
    /// Warm gold used for small "not the main accent" highlights — the
    /// "PRÁVĚ HRAJE" kicker label and the Spotify CTA. Deliberately not
    /// Spotify's own green: the redesign keeps every accent in-house rather
    /// than borrowing a third party's brand color. Adaptive for the same
    /// reason as `lavender` above.
    static let gold = Color.adaptive(light: 0x8A5E12, dark: 0xD4A24C)
    /// A legible accent purple for text/icons/borders — distinct from
    /// `brandPurple`, which is a *fixed* color deliberately kept constant
    /// for the splash screen background and decorative glows, where it's
    /// never read as foreground text against a variable background. This
    /// one adapts so it stays readable against `surface`/`background` in
    /// both appearances. No longer used by the "Najít na Spotify" pill,
    /// which reverted to `spotifyGreen` as of the 2026-08-23 redesign —
    /// kept in case another screen needs a legible purple.
    static let purpleAccent = Color.adaptive(light: 0x433785, dark: 0xA78BFA)

    /// Spotify's brand green, used by the "Najít na Spotify" action chip
    /// (`TrackDetailsRow`) — a filled, 10%-opacity tint chip rather than
    /// legible-on-dark text, so the brand color reads fine without the
    /// legibility problem the earlier `purpleAccent` swap was solving.
    /// Updated 2026-08-23 to the "Co hrálo" redesign's exact value
    /// (`#00ca47`, was `#1ed760`).
    static let spotifyGreen = Color(hex: 0x00CA47)

    // Text
    static let textPrimary = Color.adaptive(light: 0x101010, dark: 0xFFFFFF)
    static let textSecondary = Color.adaptive(light: 0x101010, dark: 0xFFFFFF, opacity: 0.6)
    static let textTertiary = Color.adaptive(light: 0x101010, dark: 0xFFFFFF, opacity: 0.4)

    // Status
    static let statusError = Color(hex: 0xE04A4F)
    static let statusLive = Color(hex: 0xFAB817)

    /// Faint hairline overlay — card borders, unfilled progress tracks,
    /// translucent pill backgrounds. Was hardcoded as `Color.white.opacity`
    /// throughout the app, which reads as a barely-there highlight against
    /// the dark background but nearly disappears in Light Mode; adapts the
    /// same way `textPrimary` does so it stays visible either way.
    static func hairline(_ opacity: Double) -> Color {
        Color.adaptive(light: 0x101010, dark: 0xFFFFFF, opacity: opacity)
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
        static let title = Font.system(.title, design: .rounded, weight: .bold)
        static let headline = Font.system(.headline, design: .rounded, weight: .semibold)
        static let body = Font.system(.body, design: .default)
        static let caption = Font.system(.caption, design: .default)
        static let nowPlayingTitle = Font.system(.title3, design: .rounded, weight: .bold)
        static let nowPlayingSubtitle = Font.system(.subheadline, design: .default, weight: .medium)

        /// Manrope — used only on the splash screen (see `SplashScreenView`),
        /// per the Figma redesign. Bundled as static TTFs under
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
        }
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

    /// A color that switches between a light- and dark-mode hex value
    /// depending on the current system appearance.
    static func adaptive(light: UInt32, dark: UInt32, opacity: Double = 1) -> Color {
        Color(UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: opacity
            )
        })
    }
}
