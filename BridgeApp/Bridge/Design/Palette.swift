import Foundation

struct BridgePalette: Sendable {
    let background: UInt32
    let card: UInt32
    let elevated: UInt32
    let textPrimary: UInt32
    let textSecondary: UInt32
    let accent: UInt32
    let onAccent: UInt32
    let assistantCard: UInt32
    let badge: UInt32

    static let light = BridgePalette(
        background: 0xEEF4FA, card: 0xFFFFFF, elevated: 0xFBFBFD,
        textPrimary: 0x101215, textSecondary: 0x596572,
        accent: 0x101215, onAccent: 0xFFFFFF, assistantCard: 0xE9E5FC, badge: 0x101215)

    static let dark = BridgePalette(
        background: 0x000000, card: 0x1C1C1E, elevated: 0x2C2C2E,
        textPrimary: 0xF5F5F7, textSecondary: 0xBEBEC3,
        accent: 0xF5F5F7, onAccent: 0x101215, assistantCard: 0x242426, badge: 0x3A3A3C)

    static let switchOn: UInt32 = 0x248A3D
    static let onBadge: UInt32 = 0xFFFFFF
    static let heroControl: UInt32 = 0x101215
    static let onHeroControl: UInt32 = 0xFFFFFF
}
