import SwiftUI

struct CardModifier: ViewModifier {
    var padding: CGFloat = Theme.Space.lg
    var radius: CGFloat = Theme.Radius.xl
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .padding(padding * min(max(scale, 1), 1.6))
            .background(Theme.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.cardBorder, lineWidth: 1)
            )
    }
}

extension View {
    func card(padding: CGFloat = Theme.Space.lg, radius: CGFloat = Theme.Radius.xl) -> some View {
        modifier(CardModifier(padding: padding, radius: radius))
    }
}

struct IconBadge: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 52

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(Theme.onBadge)
            .frame(width: size, height: size)
            .background(color, in: Circle())
            .accessibilityHidden(true)
    }
}

struct PillButtonStyle: ButtonStyle {
    var prominent = true
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title3) private var horizontalPadding: CGFloat = 22
    @ScaledMetric(relativeTo: .title3) private var verticalPadding: CGFloat = 14
    @ScaledMetric(relativeTo: .title3) private var radius: CGFloat = 28

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        configuration.label
            .font(.title3.weight(.semibold))
            .labelStyle(PillLabelStyle())
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(prominent ? Theme.onAccent : Theme.accent)
            .padding(.horizontal, min(horizontalPadding, 32))
            .padding(.vertical, min(verticalPadding, 24))
            .frame(maxWidth: .infinity, minHeight: Theme.bigControl)
            .background(prominent ? Theme.accent : Theme.accent.opacity(0.1), in: shape)
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.21), value: configuration.isPressed)
            .contentShape(shape)
    }
}

struct PillLabelStyle: LabelStyle {
    @ScaledMetric(relativeTo: .title3) private var spacing: CGFloat = 10

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: spacing) {
            configuration.icon
            configuration.title
        }
    }
}

struct BridgeToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Toggle(configuration)
            .toggleStyle(.switch)
            .tint(Theme.switchTint)
    }
}

extension View {
    @ViewBuilder
    func glassSurface<S: Shape>(_ shape: S, tint: Color? = nil, fallback: Color) -> some View {
        if #available(iOS 26.0, *) {
            background {
                if let tint {
                    Color.clear.glassEffect(.regular.tint(tint).interactive(), in: shape)
                } else {
                    Color.clear.glassEffect(.regular.interactive(), in: shape)
                }
            }
        } else {
            background(fallback, in: shape)
        }
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    static var pill: PillButtonStyle { PillButtonStyle() }
    static var pillSecondary: PillButtonStyle { PillButtonStyle(prominent: false) }
}

struct CircleControl: View {
    enum Size { case main, side }
    let title: String
    let symbol: String
    var size: Size = .side
    var tint: Color = Theme.accent
    var filled = false
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button(action: action) {
            let layout = typeSize >= .xxLarge
                ? AnyLayout(HStackLayout(spacing: Theme.Space.md))
                : AnyLayout(VStackLayout(spacing: Theme.Space.sm))
            layout {
                Image(systemName: symbol)
                    .font(.system(size: diameter * 0.36, weight: .semibold))
                    .foregroundStyle(filled ? Theme.onAccent : tint)
                    .frame(width: diameter, height: diameter)
                    .glassSurface(Circle(), tint: filled ? tint : nil, fallback: filled ? tint : Theme.card)
                Text(title)
                    .font(size == .main ? .headline : .subheadline.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(typeSize >= .xxLarge ? .leading : .center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(minWidth: 88)
            .frame(maxWidth: typeSize >= .xxLarge ? .infinity : nil, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .opacity(isEnabled ? 1 : 0.35)
        .accessibilityLabel(title)
    }

    @ScaledMetric(relativeTo: .subheadline) private var sideDiameter: CGFloat = 68

    private var diameter: CGFloat { typeSize >= .xxLarge ? 48 : size == .main ? 104 : min(sideDiameter, 80) }
}

struct PressScaleStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.21), value: configuration.isPressed)
    }
}

struct LevelBars: View {
    let level: Float
    var color: Color = Theme.recording

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { index in
                let center = abs(Float(index) - 3) / 3
                let height = 6 + CGFloat(max(0, level - center * 0.35)) * 26
                Capsule()
                    .fill(color)
                    .frame(width: 5, height: height)
            }
        }
        .frame(height: 32)
        .animation(.linear(duration: 0.08), value: level)
        .accessibilityHidden(true)
    }
}

struct StatusPill: View {
    let text: String
    var dot: Color?
    @ScaledMetric(relativeTo: .subheadline) private var horizontalPadding: CGFloat = 12
    @ScaledMetric(relativeTo: .subheadline) private var verticalPadding: CGFloat = 6

    var body: some View {
        HStack(spacing: 6) {
            if let dot { Circle().fill(dot).frame(width: 8, height: 8) }
            Text(text).font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(Theme.elevated, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.cardBorder, lineWidth: 1))
    }
}

struct ButtonRow<Content: View>: View {
    var spacing: CGFloat = Theme.Space.md
    @ViewBuilder let content: Content
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize >= .xxLarge ? AnyLayout(VStackLayout(spacing: spacing))
                                          : AnyLayout(HStackLayout(spacing: spacing))
        layout { content }
    }
}

struct ChipModifier: ViewModifier {
    @ScaledMetric(relativeTo: .subheadline) private var horizontalPadding: CGFloat = 16
    @ScaledMetric(relativeTo: .subheadline) private var verticalPadding: CGFloat = 10

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(minHeight: 44)
            .glassSurface(Capsule(), fallback: Theme.card)
    }
}

extension View {
    func chip() -> some View { modifier(ChipModifier()) }
}
