import SwiftUI

private struct AccessControllerKey: EnvironmentKey {
    static let defaultValue: AccessController? = nil
}

private struct AccessScopeKey: EnvironmentKey {
    static let defaultValue = "root"
}

private struct AccessScrollKey: EnvironmentKey {
    static let defaultValue: ScrollViewProxy? = nil
}

extension EnvironmentValues {
    var accessController: AccessController? {
        get { self[AccessControllerKey.self] }
        set { self[AccessControllerKey.self] = newValue }
    }

    var accessScope: String {
        get { self[AccessScopeKey.self] }
        set { self[AccessScopeKey.self] = newValue }
    }

    var accessScroll: ScrollViewProxy? {
        get { self[AccessScrollKey.self] }
        set { self[AccessScrollKey.self] = newValue }
    }
}

private struct AccessTargetModifier: ViewModifier {
    let id: String
    let order: Int
    let label: String
    let action: () -> Void
    @Environment(\.accessController) private var controller
    @Environment(\.accessScope) private var scope
    @Environment(\.accessScroll) private var scroll
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content
            .overlay {
                if let controller {
                    FocusRing(focus: controller.focus, key: key)
                }
            }
            .id(key)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                report(frame)
            }
            .onChange(of: isEnabled) { _, enabled in
                if !enabled { controller?.unregister(key) }
            }
            .onDisappear { controller?.unregister(key) }
    }

    private var key: String { "\(scope)/\(id)" }

    private func report(_ frame: CGRect) {
        guard isEnabled else { controller?.unregister(key); return }
        controller?.register(.init(id: key, scope: scope, order: order, frame: frame, label: label,
                                   action: action, scrollable: scroll != nil))
    }
}

extension View {
    func accessTarget(_ id: String, label: String, order: Int = 0, action: @escaping () -> Void) -> some View {
        modifier(AccessTargetModifier(id: id, order: order, label: label, action: action))
    }

    func accessScrolling() -> some View {
        ScrollViewReader { proxy in
            self.environment(\.accessScroll, proxy)
        }
    }

    func accessHost(_ scope: String, controller: AccessController) -> some View {
        modifier(AccessHostModifier(scope: scope, controller: controller))
    }
}

private struct FocusRing: View {
    @ObservedObject var focus: FocusPublisher
    let key: String
    @Environment(\.accessScroll) private var scroll

    var body: some View {
        ZStack {
            if focus.id == key {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Theme.accent, lineWidth: 5)
                    .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.accent.opacity(0.10)))
                    .padding(-7)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: focus.id) { _, id in
            guard id == key, let scroll else { return }
            withAnimation(.easeOut(duration: 0.3)) { scroll.scrollTo(key, anchor: .center) }
        }
    }
}

private struct AccessHostModifier: ViewModifier {
    let scope: String
    @ObservedObject var controller: AccessController

    func body(content: Content) -> some View {
        content
            .environment(\.accessController, controller)
            .environment(\.accessScope, scope)
            .overlay {
                AccessOverlay(controller: controller, scope: scope)
                    .ignoresSafeArea()
            }
            .background {
                SwitchKeyCatcher(isActive: controller.method != .touch && controller.topScope == scope) { key in
                    switch key {
                    case .select: controller.select()
                    case .step: controller.step()
                    }
                }
                .frame(width: 0, height: 0)
            }
            .onAppear { if scope != "root" { controller.push(scope: scope) } }
            .onDisappear { if scope != "root" { controller.pop(scope: scope) } }
    }
}

private struct AccessOverlay: View {
    @ObservedObject var controller: AccessController
    @ObservedObject var settings: AppSettings
    let scope: String
    @State private var holdProgress = false

    init(controller: AccessController, scope: String) {
        self.controller = controller
        self.settings = controller.settings
        self.scope = scope
    }

    var body: some View {
        GeometryReader { proxy in
            let origin = controller.windowOrigin(for: scope) ?? proxy.frame(in: .global).origin
            ZStack(alignment: .topLeading) {
                if isActive && controller.method == .scanning && !controller.isPaused {
                    Color.black.opacity(0.001)
                        .contentShape(Rectangle())
                        .onTapGesture { controller.select() }
                        .onLongPressGesture(minimumDuration: 3) {
                            settings.control = .touch
                            controller.restart()
                            AccessibilityNotification.Announcement("Touch control is back on.").post()
                        }
                        .accessibilityHidden(true)
                }
                if isActive, let point = controller.pointer {
                    pointer(at: CGPoint(x: point.x - origin.x, y: point.y - origin.y))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                WindowFrameReader { frame in controller.setHostWindow(scope, frame) }
            }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                controller.setHostGlobal(scope, frame)
            }
            .onAppear { if scope == "root" { controller.screen = proxy.frame(in: .global) } }
            .onChange(of: proxy.size) { _, _ in if scope == "root" { controller.screen = proxy.frame(in: .global) } }
        }
        .allowsHitTesting(isActive && controller.method == .scanning && !controller.isPaused)
    }

    private var isActive: Bool { controller.method != .touch && controller.topScope == scope }

    private func pointer(at point: CGPoint) -> some View {
        Circle()
            .fill(Theme.accent)
            .overlay(Circle().strokeBorder(Theme.onAccent, lineWidth: 3))
            .overlay {
                if settings.headSelect == .dwell, controller.dwellProgress > 0 {
                    Circle()
                        .trim(from: 0, to: controller.dwellProgress)
                        .stroke(Theme.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(-10)
                }
            }
            .overlay {
                if controller.scrollHint != 0 {
                    Image(systemName: controller.scrollHint > 0 ? "chevron.down" : "chevron.up")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(Theme.onAccent)
                }
            }
            .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
            .frame(width: 28, height: 28)
            .offset(x: point.x - 14, y: point.y - 14)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

#if os(iOS)
private struct WindowFrameReader: UIViewRepresentable {
    let onReady: (@escaping () -> CGRect?) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        onReady { [weak view] in
            guard let view, view.window != nil else { return nil }
            return view.convert(view.bounds, to: nil)
        }
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {}
}

private struct SwitchKeyCatcher: UIViewRepresentable {
    enum Key { case select, step }
    let isActive: Bool
    let onKey: (Key) -> Void

    func makeUIView(context: Context) -> KeyView {
        let view = KeyView()
        view.onKey = onKey
        return view
    }

    func updateUIView(_ view: KeyView, context: Context) {
        view.onKey = onKey
        view.isActive = isActive
    }

    final class KeyView: UIView {
        var onKey: ((Key) -> Void)?
        var isActive = false {
            didSet { if isActive { claim() } }
        }
        private var timer: Timer?

        override var canBecomeFirstResponder: Bool { isActive }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            timer?.invalidate()
            guard window != nil else { return }
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.claim() }
            }
        }

        private func claim() {
            guard isActive, window != nil, !isFirstResponder else { return }
            becomeFirstResponder()
        }

        override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            var handled = false
            for press in presses {
                guard let key = press.key else { continue }
                switch key.keyCode {
                case .keyboardSpacebar, .keyboardReturnOrEnter, .keypadEnter:
                    onKey?(.select); handled = true
                case .keyboardTab, .keyboardRightArrow, .keyboardDownArrow:
                    onKey?(.step); handled = true
                default:
                    break
                }
            }
            if !handled { super.pressesBegan(presses, with: event) }
        }
    }
}
#else
private struct WindowFrameReader: View {
    let onReady: (@escaping () -> CGRect?) -> Void
    var body: some View { EmptyView() }
}

private struct SwitchKeyCatcher: View {
    enum Key { case select, step }
    let isActive: Bool
    let onKey: (Key) -> Void
    var body: some View { EmptyView() }
}
#endif
