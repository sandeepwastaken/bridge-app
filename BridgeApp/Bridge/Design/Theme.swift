import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum Theme {
    static let background = color(\.background)
    static let card = color(\.card)
    static let elevated = color(\.elevated)
    static let textPrimary = color(\.textPrimary)
    static let textSecondary = color(\.textSecondary)
    static let accent = color(\.accent)
    static let onAccent = color(\.onAccent)
    static let assistantCard = color(\.assistantCard)
    static let badge = color(\.badge)
    static let onBadge = Color(hex: BridgePalette.onBadge)
    static let switchTint = Color(hex: BridgePalette.switchOn)
    static let heroControl = Color(hex: BridgePalette.heroControl)
    static let onHeroControl = Color(hex: BridgePalette.onHeroControl)
    static let cardBorder = Color.adaptive(light: 0x000000, dark: 0xFFFFFF, lightAlpha: 0.06, darkAlpha: 0.10)
    static let recording = Color(.systemRed)
    static let unsure = Color.adaptive(light: 0xFFE58F, dark: 0x5C4A00)

    private static func color(_ key: KeyPath<BridgePalette, UInt32>) -> Color {
        Color.adaptive(light: BridgePalette.light[keyPath: key], dark: BridgePalette.dark[keyPath: key])
    }

    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum Radius {
        static let md: CGFloat = 14
        static let lg: CGFloat = 24
        static let xl: CGFloat = 28
    }

    static func message(for text: String) -> Font {
        .system(.largeTitle, design: .default, weight: text.containsDevanagari ? .semibold : .bold)
    }

    static let gutter: CGFloat = 20
    static let bigControl: CGFloat = 56
}

extension String {
    var containsDevanagari: Bool {
        unicodeScalars.contains { (0x0900...0x097F).contains($0.value) }
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

    static func adaptive(light: UInt32, dark: UInt32, lightAlpha: Double = 1, darkAlpha: Double = 1) -> Color {
        #if canImport(UIKit)
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(Color(hex: dark, alpha: darkAlpha))
                : UIColor(Color(hex: light, alpha: lightAlpha))
        })
        #else
        Color(hex: light, alpha: lightAlpha)
        #endif
    }
}
