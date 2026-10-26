import SwiftUI

@MainActor
final class AccessController: ObservableObject {
    struct Target {
        let id: String
        let scope: String
        let order: Int
        var frame: CGRect
        let label: String
        var action: () -> Void
        var scrollable = false
    }

    @Published private(set) var focusedID: String? {
        didSet { if focus.id != focusedID { focus.id = focusedID } }
    }
    @Published private(set) var focusFrame: CGRect?
    @Published private(set) var pointer: CGPoint?
    @Published private(set) var dwellProgress: Double = 0
    @Published private(set) var scrollHint = 0
    @Published private(set) var lastSample: HeadTracker.Sample?
    @Published var isPaused = false {
        didSet { if isPaused != oldValue { restart() } }
    }
    @Published private(set) var scopes: [String] = ["root"]

    let focus = FocusPublisher()

    let settings: AppSettings
    let head = HeadTracker()
    var screen: CGRect = .zero

    private var targets: [String: Target] = [:]
    private var scanTask: Task<Void, Never>?
    private var recenterTask: Task<Void, Never>?
    private var hoverID: String?
    private var hoverStart: Date?
    private var edgeStart: Date?
    private var cooldownUntil = Date.distantPast
    private var neutral: (yaw: Float, pitch: Float)?
    private var smoothed: CGPoint?
    private var headClients: Set<String> = []
    private var hostGlobals: [String: CGRect] = [:]
    private var hostWindows: [String: () -> CGRect?] = [:]

    init(settings: AppSettings) {
        self.settings = settings
        head.onSample = { [weak self] sample in self?.handle(sample) }
    }

    var method: ControlMethod { settings.control }
    var topScope: String { scopes.last ?? "root" }

    func register(_ target: Target) {
        targets[target.id] = target
        if target.id == focusedID { focusFrame = target.frame }
    }

    func unregister(_ id: String) {
        targets[id] = nil
        if focusedID == id { focusedID = nil; focusFrame = nil }
    }

    func push(scope: String) {
        scopes.append(scope)
        restart()
    }

    func pop(scope: String) {
        if let index = scopes.lastIndex(of: scope) { scopes.remove(at: index) }
        restart()
    }

    var ordered: [Target] {
        targets.values
            .filter { $0.scope == topScope && $0.frame.width > 1 }
            .sorted { a, b in
                if a.order != b.order { return a.order < b.order }
                if abs(a.frame.minY - b.frame.minY) > 8 { return a.frame.minY < b.frame.minY }
                return a.frame.minX < b.frame.minX
            }
    }

    func restart() {
        scanTask?.cancel()
        focusedID = nil
        focusFrame = nil
        dwellProgress = 0
        hoverID = nil
        scrollHint = 0
        edgeStart = nil
        updateHead()
        guard method == .scanning, !isPaused else { return }
        scanTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            while !Task.isCancelled {
                guard let self else { return }
                self.advance()
                try? await Task.sleep(for: .seconds(max(0.6, self.settings.scanInterval)))
            }
        }
    }

    private func advance() {
        let list = ordered
        guard !list.isEmpty else { focusedID = nil; focusFrame = nil; return }
        let next: Target
        if let current = focusedID, let index = list.firstIndex(where: { $0.id == current }) {
            next = list[(index + 1) % list.count]
        } else {
            next = list[0]
        }
        focusedID = next.id
        focusFrame = next.frame
        AccessibilityNotification.Announcement(next.label).post()
    }

    func select() {
        if isPaused {
            isPaused = false
            AccessibilityNotification.Announcement("Hands-free is back on.").post()
            return
        }
        switch method {
        case .scanning:
            guard !isPaused, let id = focusedID, let target = targets[id] else { return }
            fire(target)
            restart()
        case .head:
            if let id = hoverID, let target = targets[id] { fire(target) }
        case .touch:
            break
        }
    }

    func step() {
        guard method == .scanning else { return }
        scanTask?.cancel()
        advance()
        scanTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.restart()
        }
    }

    private func fire(_ target: Target) {
        guard Date() >= cooldownUntil else { return }
        cooldownUntil = Date().addingTimeInterval(0.8)
        Haptics.selection()
        target.action()
    }

    func useHead(_ client: String, _ on: Bool) {
        if on { headClients.insert(client) } else { headClients.remove(client) }
        updateHead()
    }

    func recenter(after delay: Duration = .seconds(1.5)) {
        recenterTask?.cancel()
        AccessibilityNotification.Announcement("Look at the middle of the screen.").post()
        recenterTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            self.neutral = nil
            self.smoothed = nil
        }
    }

    private func updateHead() {
        let wanted = (method == .head && !isPaused) || !headClients.isEmpty
        if wanted, !head.isRunning {
            neutral = nil
            head.start()
        } else if !wanted, head.isRunning {
            head.stop()
            pointer = nil
        }
        if method != .head || isPaused { pointer = nil }
    }

    func handle(_ raw: HeadTracker.Sample) {
        if neutral == nil { neutral = (raw.yaw, raw.pitch) }
        guard let neutral else { return }
        var sample = raw
        sample.yaw -= neutral.yaw
        sample.pitch -= neutral.pitch
        lastSample = sample

        guard method == .head, !isPaused, !screen.isEmpty else { return }
        let speed = CGFloat(settings.pointerSpeed)
        let gainX = (screen.width / 2) / 0.28 * speed
        let gainY = (screen.height / 2) / 0.22 * speed
        let target = CGPoint(
            x: screen.midX + CGFloat(sample.yaw) * gainX,
            y: screen.midY - CGFloat(sample.pitch) * gainY
        )
        let previous = smoothed ?? target
        let next = CGPoint(x: previous.x + (target.x - previous.x) * 0.3,
                           y: previous.y + (target.y - previous.y) * 0.3)
        let clamped = CGPoint(x: min(max(next.x, screen.minX + 12), screen.maxX - 12),
                              y: min(max(next.y, screen.minY + 12), screen.maxY - 12))
        smoothed = clamped
        pointer = clamped
        track(at: clamped, gesture: gestureFired(sample))
    }

    private var gestureArmed = true

    private func gestureFired(_ sample: HeadTracker.Sample) -> Bool {
        let value: Float
        switch settings.headSelect {
        case .dwell: return false
        case .openMouth: value = sample.jawOpen
        case .raiseEyebrows: value = sample.browUp
        case .smile: value = sample.smile
        }
        if value > 0.5, gestureArmed {
            gestureArmed = false
            return true
        }
        if value < 0.25 { gestureArmed = true }
        return false
    }

    func setHostGlobal(_ scope: String, _ frame: CGRect) {
        hostGlobals[scope] = frame
    }

    func setHostWindow(_ scope: String, _ frame: @escaping () -> CGRect?) {
        hostWindows[scope] = frame
    }

    func windowOrigin(for scope: String) -> CGPoint? {
        hostWindows[scope]?()?.origin
    }

    private func offset(for scope: String) -> CGPoint {
        guard let global = hostGlobals[scope], let window = hostWindows[scope]?() else { return .zero }
        return CGPoint(x: window.minX - global.minX, y: window.minY - global.minY)
    }

    private func screenTargets() -> [(target: Target, frame: CGRect)] {
        let shift = offset(for: topScope)
        return ordered.map { ($0, $0.frame.offsetBy(dx: shift.x, dy: shift.y)) }
    }

    private func track(at point: CGPoint, gesture: Bool) {
        let hit = screenTargets().last { $0.frame.insetBy(dx: -6, dy: -6).contains(point) }?.target
        if hit?.id != hoverID {
            hoverID = hit?.id
            hoverStart = Date()
            dwellProgress = 0
        }
        focusedID = hit?.id
        focusFrame = hit?.frame
        guard let hit else { edgeScroll(at: point); return }
        if scrollHint != 0 { scrollHint = 0 }
        if settings.headSelect == .dwell {
            let elapsed = Date().timeIntervalSince(hoverStart ?? Date())
            dwellProgress = min(1, elapsed / max(0.5, settings.dwellTime))
            if dwellProgress >= 1 {
                fire(hit)
                hoverStart = Date().addingTimeInterval(1.0)
                dwellProgress = 0
            }
        } else if gesture {
            fire(hit)
        }
    }

    private func edgeScroll(at point: CGPoint) {
        let band: CGFloat = 40
        let direction = point.y >= screen.maxY - band ? 1 : (point.y <= screen.minY + band ? -1 : 0)
        if direction != scrollHint {
            scrollHint = direction
            edgeStart = Date()
        }
        guard direction != 0, let start = edgeStart, Date().timeIntervalSince(start) >= 0.6 else { return }
        edgeStart = Date()
        let reach = screen.height * 0.15
        let candidates = screenTargets().filter(\.target.scrollable)
        let next = direction > 0
            ? candidates.filter { $0.frame.maxY > screen.maxY - reach }.min { $0.frame.minY < $1.frame.minY }
            : candidates.filter { $0.frame.minY < screen.minY + reach }.max { $0.frame.minY < $1.frame.minY }
        guard let next else { return }
        focusedID = next.target.id
        focusFrame = next.target.frame
    }
}

@MainActor
enum Haptics {
    static var enabled = true

    static func listeningChanged() {
        #if os(iOS)
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    static func selection() {
        #if os(iOS)
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        #endif
    }
}

@MainActor
final class FocusPublisher: ObservableObject {
    @Published var id: String?
}
