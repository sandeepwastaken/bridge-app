import Foundation
import Testing
@testable import Bridge

struct PaletteContrastTests {
    @Test func textAndPlaceholdersStayReadableOnEveryContentSurface() {
        for palette in [BridgePalette.light, BridgePalette.dark] {
            for surface in [palette.background, palette.card, palette.elevated, palette.assistantCard] {
                #expect(contrast(palette.textPrimary, surface) >= 4.5)
                #expect(contrast(palette.textSecondary, surface) >= 4.5)
            }
        }
    }

    @Test func badgesAndPrimaryControlsUseContrastingForegrounds() {
        for palette in [BridgePalette.light, BridgePalette.dark] {
            #expect(contrast(palette.onAccent, palette.accent) >= 7)
            #expect(contrast(BridgePalette.onBadge, palette.badge) >= 7)
        }
    }

    @Test func settingsGearHasContrastOnItsFixedBackground() {
        #expect(contrast(BridgePalette.onHeroControl, BridgePalette.heroControl) >= 7)
    }

    @Test func switchesHaveVisibleWhiteThumbsAndVisibleTracks() {
        #expect(contrast(0xFFFFFF, BridgePalette.switchOn) >= 3)
        for palette in [BridgePalette.light, BridgePalette.dark] {
            #expect(contrast(BridgePalette.switchOn, palette.card) >= 3)
        }
    }

    @Test func darkSurfacesAndControlsStayNeutral() {
        let palette = BridgePalette.dark
        for color in [palette.background, palette.card, palette.elevated, palette.accent, palette.assistantCard, palette.badge] {
            let channels = [Int(color >> 16 & 255), Int(color >> 8 & 255), Int(color & 255)]
            #expect(channels.max()! - channels.min()! <= 3)
        }
    }

    private func contrast(_ first: UInt32, _ second: UInt32) -> Double {
        let a = luminance(first)
        let b = luminance(second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    private func luminance(_ color: UInt32) -> Double {
        func linear(_ component: UInt32) -> Double {
            let value = Double(component & 255) / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(color >> 16) + 0.7152 * linear(color >> 8) + 0.0722 * linear(color)
    }
}
