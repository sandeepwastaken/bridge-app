import CoreGraphics
import Testing
@testable import Bridge

@MainActor
struct AccessControllerTests {
    private func makeController(_ method: ControlMethod = .scanning) -> AccessController {
        let settings = AppSettings(defaults: isolatedDefaults())
        settings.control = method
        return AccessController(settings: settings)
    }

    private func target(_ id: String, scope: String = "root", order: Int = 0,
                        x: CGFloat = 0, y: CGFloat, action: @escaping () -> Void = {}) -> AccessController.Target {
        .init(id: id, scope: scope, order: order, frame: CGRect(x: x, y: y, width: 100, height: 50),
              label: id, action: action)
    }

    @Test func controlsAreVisitedByGroupThenTopToBottomThenLeftToRight() {
        let access = makeController()
        access.register(target("bottom", y: 600))
        access.register(target("top-right", x: 200, y: 100))
        access.register(target("top-left", x: 0, y: 100))
        access.register(target("go-back", order: 100, y: 0))
        access.register(target("first-group", order: -1, y: 900))

        #expect(access.ordered.map(\.id) == ["first-group", "top-left", "top-right", "bottom", "go-back"])
    }

    @Test func onlyTheFrontLayerIsScanned() {
        let access = makeController()
        access.register(target("home", y: 0))
        access.register(target("sheet-done", scope: "fix", y: 0))

        #expect(access.ordered.map(\.id) == ["home"])
        access.push(scope: "fix")
        #expect(access.ordered.map(\.id) == ["sheet-done"])
        access.pop(scope: "fix")
        #expect(access.ordered.map(\.id) == ["home"])
    }

    @Test func removedControlsAreNoLongerScanned() {
        let access = makeController()
        access.register(target("a", y: 0))
        access.register(target("b", y: 100))
        access.unregister("a")
        #expect(access.ordered.map(\.id) == ["b"])
    }

    @Test func steppingLightsEachControlAndWrapsAround() {
        let access = makeController()
        access.register(target("a", y: 0))
        access.register(target("b", y: 100))

        access.step()
        #expect(access.focusedID == "a")
        access.step()
        #expect(access.focusedID == "b")
        access.step()
        #expect(access.focusedID == "a")
    }

    @Test func aSwitchPressChoosesTheLitControl() {
        let access = makeController()
        var chosen: [String] = []
        access.register(target("speak", y: 0) { chosen.append("speak") })
        access.register(target("translate", y: 100) { chosen.append("translate") })

        access.step()
        access.step()
        access.select()
        #expect(chosen == ["translate"])
    }

    @Test func pressingTwiceQuicklyChoosesOnlyOnce() {
        let access = makeController()
        var count = 0
        access.register(target("speak", y: 0) { count += 1 })

        access.step()
        access.select()
        access.step()
        access.select()
        #expect(count == 1, "A short cooldown stops a tremor from choosing twice")
    }

    @Test func whilePausedASwitchPressResumesInsteadOfChoosing() {
        let access = makeController()
        var count = 0
        access.register(target("speak", y: 0) { count += 1 })
        access.isPaused = true

        access.select()
        #expect(access.isPaused == false)
        #expect(count == 0)
    }

    @Test func touchModeIgnoresSwitchPresses() {
        let access = makeController(.touch)
        var count = 0
        access.register(target("speak", y: 0) { count += 1 })
        access.step()
        access.select()
        #expect(count == 0)
        #expect(access.focusedID == nil)
    }

    @Test func scanningStartsOnItsOwnAfterAShortPause() async throws {
        let access = makeController()
        access.settings.scanInterval = 30
        access.register(target("speak", y: 0))
        access.restart()
        try await Task.sleep(for: .milliseconds(700))
        #expect(access.focusedID == "speak")
    }

    private func headController() -> AccessController {
        let access = makeController(.head)
        access.screen = CGRect(x: 0, y: 0, width: 400, height: 800)
        access.settings.pointerSpeed = 1
        return access
    }

    private func look(_ access: AccessController, yaw: Float, pitch: Float, times: Int = 40) {
        for _ in 0..<times {
            access.handle(.init(yaw: yaw, pitch: pitch, jawOpen: 0, browUp: 0, smile: 0))
        }
    }

    @Test func turningTowardYourRightIsAPositiveYaw() {
        #expect(HeadTracker.angles(forward: SIMD4(0.3, 0, 0.95, 0)).yaw > 0)
        #expect(HeadTracker.angles(forward: SIMD4(-0.3, 0, 0.95, 0)).yaw < 0)
        #expect(HeadTracker.angles(forward: SIMD4(0, 0.3, 0.95, 0)).pitch > 0)
    }

    @Test func thePointerFollowsTheHeadWithoutMirroring() {
        let access = headController()
        look(access, yaw: 0, pitch: 0, times: 1)
        look(access, yaw: 0.1, pitch: 0)
        #expect((access.pointer?.x ?? 0) > 200)
        look(access, yaw: -0.1, pitch: 0)
        #expect((access.pointer?.x ?? 400) < 200)
        look(access, yaw: 0, pitch: 0.1)
        #expect((access.pointer?.y ?? 800) < 400)
        look(access, yaw: 0, pitch: -0.1)
        #expect((access.pointer?.y ?? 0) > 400)
    }

    @Test func holdingStillOnAControlChoosesIt() async throws {
        let access = headController()
        access.settings.headSelect = .dwell
        access.settings.dwellTime = 0.6
        var chosen = 0
        access.register(target("middle", x: 150, y: 375) { chosen += 1 })
        look(access, yaw: 0, pitch: 0)
        #expect(access.focusedID == "middle")
        try await Task.sleep(for: .milliseconds(700))
        look(access, yaw: 0, pitch: 0, times: 1)
        #expect(chosen == 1)
    }

    @Test func pushingAgainstTheBottomEdgeBringsLowerControlsIntoView() async throws {
        let access = headController()
        var below = target("below", y: 900)
        below.scrollable = true
        access.register(below)
        access.register(target("tab", y: 680))
        look(access, yaw: 0, pitch: 0, times: 1)
        look(access, yaw: 0, pitch: -0.5)
        #expect(access.scrollHint == 1)
        try await Task.sleep(for: .milliseconds(700))
        look(access, yaw: 0, pitch: -0.5, times: 1)
        #expect(access.focusedID == "below")
    }

    @Test func controlsInASheetAreHitWhereTheyAppearOnScreen() {
        let access = headController()
        access.push(scope: "sheet")
        access.setHostGlobal("sheet", CGRect(x: 0, y: 0, width: 400, height: 700))
        access.setHostWindow("sheet") { CGRect(x: 0, y: 100, width: 400, height: 700) }
        access.register(target("save", scope: "sheet", x: 150, y: 25))
        look(access, yaw: 0, pitch: 0, times: 1)
        look(access, yaw: 0, pitch: 0.1375)
        #expect(access.focusedID == "save")
        look(access, yaw: 0, pitch: 0.275)
        #expect(access.focusedID == nil)
    }

    @Test func headPointerIsUnavailableInTheSimulator() {
        #if targetEnvironment(simulator)
        #expect(HeadTracker.isSupported == false)
        #endif
    }
}
