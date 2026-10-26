import XCTest

final class ReadmeScreenshots: XCTestCase {
    private var folder: URL?

    override func setUpWithError() throws {
        continueAfterFailure = false
        guard let path = ProcessInfo.processInfo.environment["README_SHOTS"], !path.isEmpty else {
            throw XCTSkip("Set README_SHOTS to a folder to capture README screenshots.")
        }
        folder = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: folder!, withIntermediateDirectories: true)
    }

    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        let extra = ProcessInfo.processInfo.environment["README_ARGS"]?.split(separator: " ").map(String.init) ?? []
        app.launchArguments = ["-uitesting", "-onboarded", "YES", "-partnerName", "Asha"] + extra + arguments
        app.launch()
        return app
    }

    private func save(_ name: String) throws {
        sleep(1)
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try data.write(to: folder!.appendingPathComponent("\(name).png"))
    }

    private func typeWords(_ app: XCUIApplication, _ text: String) {
        app.buttons["Type"].tap()
        let editor = app.textViews["Your words"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.typeText(text)
        app.buttons["Use these words"].tap()
    }

    func testHome() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["home.speak"].waitForExistence(timeout: 5))
        try save("home")
    }

    func testSpeak() throws {
        let app = launch()
        app.buttons["home.speak"].tap()
        typeWords(app, "Please give me a moment.")
        XCTAssertTrue(app.buttons["Speak my words"].waitForExistence(timeout: 5))
        try save("speak")
    }

    func testShowBig() throws {
        let app = launch()
        app.buttons["home.speak"].tap()
        typeWords(app, "Please give me a moment.")
        app.buttons["Show big"].tap()
        XCTAssertTrue(app.buttons["Turn around"].waitForExistence(timeout: 5))
        try save("show")
    }

    func testAssist() throws {
        let app = launch()
        app.buttons["Assist"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Hello. What do you need?"].waitForExistence(timeout: 5))
        try save("assist")
    }

    func testPhrases() throws {
        let app = launch()
        app.buttons["home.phrases"].tap()
        XCTAssertTrue(app.staticTexts["Right now"].waitForExistence(timeout: 5))
        try save("phrases")
    }

    func testReader() throws {
        let app = launch()
        let read = app.buttons["home.read"]
        XCTAssertTrue(read.waitForExistence(timeout: 5))
        read.tap()
        let editor = app.textViews["reader.source"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("Your appointment with Dr. Rao is on Tuesday at 10:30. Please bring your insurance card. The weather has been lovely this week. Parking is free behind the clinic. If you cannot come, call the clinic before Monday.")
        app.buttons["reader.keyboardDone"].tap()
        app.buttons["Key sentences"].tap()
        XCTAssertTrue(app.staticTexts["Key sentences, word for word"].waitForExistence(timeout: 5))
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
        start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.32)))
        try save("reader")
    }

    func testTalkTogether() throws {
        let app = launch()
        app.buttons["home.talk"].tap()
        XCTAssertTrue(app.buttons["talk.flip"].waitForExistence(timeout: 5))
        try save("talk-together")
    }

    func testHandsFree() throws {
        let app = launch()
        app.buttons["Settings"].firstMatch.tap()
        app.buttons["How you control Bridge, Touch"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Choose with"].waitForExistence(timeout: 5))
        try save("control")
    }
}
