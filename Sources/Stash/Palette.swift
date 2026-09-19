import SwiftUI

/// Colour set for one appearance. Every view reads this rather than hard-coding
/// colours, so a theme switch is a single swap.
struct Palette {
    var background: Color
    var divider: Color
    var text: Color
    var muted: Color
    var faint: Color
    var fill: Color
    var selection: Color
    var contrast: Color

    static let dark = Palette(
        background: .black,
        divider: .white.opacity(0.07),
        text: .white.opacity(0.94),
        muted: .white.opacity(0.50),
        faint: .white.opacity(0.32),
        fill: .white.opacity(0.07),
        selection: .white.opacity(0.11),
        contrast: .white
    )

    static let light = Palette(
        background: Color(white: 0.99),
        divider: .black.opacity(0.09),
        text: .black.opacity(0.88),
        muted: .black.opacity(0.52),
        faint: .black.opacity(0.36),
        fill: .black.opacity(0.05),
        selection: .black.opacity(0.07),
        contrast: .black
    )

    static func resolved(for scheme: ColorScheme) -> Palette {
        scheme == .dark ? .dark : .light
    }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette.dark
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

/// Motion borrowed from maaa: the panel unfurls by growing its height from zero,
/// clipped as it goes, rather than sliding a finished rectangle into place.
enum Motion {
    /// cubic-bezier(.22, 1, .36, 1) — the curve maaa uses throughout.
    static let unfurl = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.48)
    static let collapse = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.34)
    static let content = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.32)
    static let swap = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.26)
}
