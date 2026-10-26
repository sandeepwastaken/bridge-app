import XCTest
import UIKit

final class BridgeUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @discardableResult
    private func launch(_ arguments: [String] = ["-onboarded", "YES"]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitesting"] + arguments
        app.launch()
        return app
    }

    private func waitFor(_ element: XCUIElement, timeout: TimeInterval = 5,
                         file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Missing: \(element)", file: file, line: line)
    }

    func testWelcomeFlowLeadsToHome() {
        let app = launch([])
        waitFor(app.staticTexts["Welcome to Bridge"])
        app.buttons["Get started"].tap()

        waitFor(app.staticTexts["How do you like to use your phone?"])
        XCTAssertTrue(app.buttons["method.touch"].exists)
        XCTAssertTrue(app.buttons["method.scanning"].exists)
        app.buttons["Continue"].tap()

        waitFor(app.staticTexts["Which languages?"])
        app.buttons["Continue"].tap()

        waitFor(app.staticTexts["Use the microphone?"])
        app.buttons["Not now"].tap()

        waitFor(app.staticTexts["How can I help?"])
    }

    func testHomeOffersEveryChoice() {
        let app = launch()
        for id in ["home.speak", "home.translate", "home.talk", "home.read", "home.phrases", "home.settings"] {
            waitFor(app.buttons[id])
        }
    }

    func testReaderPreservesParagraphsAndCanClearText() {
        let app = launch()
        let read = app.buttons["home.read"]
        waitFor(read)
        if !read.isHittable { app.swipeUp() }
        read.tap()
        let editor = app.textViews["reader.source"]
        waitFor(editor)
        editor.tap()
        editor.typeText("Appointment: 10:30.\nBring ID.\n\nArrive early.")
        app.buttons["reader.keyboardDone"].tap()
        app.buttons["Start reading"].tap()
        waitFor(app.staticTexts["Paragraph 1 of 2"])
        XCTAssertEqual(app.staticTexts["reader.paragraph"].label, "Appointment: 10:30.\nBring ID.")
        if !app.buttons["Next"].isHittable { app.swipeUp() }
        app.buttons["Next"].tap()
        waitFor(app.staticTexts["Arrive early."])
        app.buttons["Clear text"].tap()
        XCTAssertFalse(app.staticTexts["reader.paragraph"].exists)
        attachScreenshot(app, named: "Reader cleared")
    }

    func testImportantInformationIsReachableFromSettings() {
        let app = launch()
        let settings = app.buttons["home.settings"]
        waitFor(settings)
        if !settings.isHittable { app.swipeUp() }
        settings.tap()
        let link = app.buttons["Privacy & important information"]
        for _ in 0..<6 where !link.isHittable { app.swipeUp() }
        link.tap()
        waitFor(app.staticTexts["Your words, your choice"])
        attachScreenshot(app, named: "Important information")
    }

    func testTypedWordsCanBeSaidAloud() {
        let app = launch()
        app.buttons["home.speak"].tap()

        app.buttons["Type"].tap()
        let editor = app.textViews["Your words"]
        waitFor(editor)
        editor.typeText("Please bring my glasses.")
        app.buttons["Use these words"].tap()

        waitFor(app.staticTexts["Please bring my glasses."])
        waitFor(app.staticTexts["Ready to say"])
        XCTAssertTrue(app.buttons["Fix words"].exists)
        XCTAssertTrue(app.buttons["Show big"].exists)
        attachScreenshot(app, named: "Speak for me")

        app.buttons["Speak my words"].tap()
        let spoke = NSPredicate { _, _ in
            app.staticTexts["Speaking"].exists || app.staticTexts["Said"].exists
        }
        expectation(for: spoke, evaluatedWith: nil)
        waitForExpectations(timeout: 10)
        waitFor(app.buttons["Say again"], timeout: 15)
    }

    func testShowBigTurnsAroundForTheListener() {
        let app = launch()
        app.buttons["home.speak"].tap()
        app.buttons["Type"].tap()
        app.textViews["Your words"].typeText("Thank you.")
        app.buttons["Use these words"].tap()

        app.buttons["Show big"].tap()
        waitFor(app.buttons["Turn around"])
        app.buttons["Turn around"].tap()
        waitFor(app.buttons["Turn back"])
        app.buttons["Done"].tap()
        waitFor(app.buttons["Speak my words"])
    }

    private func translateTyped(_ text: String, stub: String) -> XCUIApplication {
        let app = launch(["-onboarded", "YES", "-stubTranslation", stub])
        app.buttons["home.translate"].tap()
        app.buttons["Type"].tap()
        let editor = app.textViews["Your words"]
        waitFor(editor)
        editor.typeText(text)
        app.buttons["Use these words"].tap()
        return app
    }

    func testTranslationNamesTheLanguageItWillSpeak() {
        let app = translateTyped("I need some water.", stub: "ok")
        waitFor(app.staticTexts["[Hindi] I need some water."])
        waitFor(app.buttons["Say in Hindi"])
    }

    func testFailedTranslationIsNeverPassedOffAsHindi() {
        let app = translateTyped("I need some water.", stub: "fail")
        waitFor(app.staticTexts["Couldn't translate into Hindi. Say it will use English."])
        waitFor(app.buttons["Say in English"])
        XCTAssertFalse(app.buttons["Say in Hindi"].exists)
        XCTAssertTrue(app.buttons["Try translating again"].exists)
    }

    func testTranslationThatNeverAnswersDoesNotTrapThePerson() {
        let app = translateTyped("I need some water.", stub: "hang")
        if app.buttons["Close"].waitForExistence(timeout: 3) { app.buttons["Close"].tap() }
        waitFor(app.buttons["Say in English"], timeout: 10)
        XCTAssertFalse(app.buttons["Translating"].exists)
    }

    func testTalkTogetherAcceptsTypedWords() {
        let app = launch(["-onboarded", "YES", "-stubTranslation", "ok", "-autoSpeakTurns", "NO"])
        app.buttons["home.talk"].tap()
        app.buttons["Type"].tap()
        let editor = app.textViews["Your words"]
        waitFor(editor)
        editor.typeText("Where is the bathroom?")
        app.buttons["Use these words"].tap()

        waitFor(app.staticTexts["Where is the bathroom?"])
        waitFor(app.staticTexts["[Hindi] Where is the bathroom?"])
        attachScreenshot(app, named: "Talk together")
    }

    func testQuickPhrasesCanBeSaidInTheListenersLanguage() {
        let app = launch()
        app.buttons["home.phrases"].tap()
        waitFor(app.staticTexts["Right now"])

        app.descendants(matching: .any)["phrases.languagePicker"].tap()
        app.buttons["sayin.en-US"].tap()
        attachScreenshot(app, named: "Quick phrases English")
        app.descendants(matching: .any)["phrases.languagePicker"].tap()
        app.buttons["sayin.hi-IN"].tap()
        XCTAssertTrue(app.staticTexts["हिन्दी"].exists)
        app.buttons["मुझे पानी चाहिए।"].tap()
        waitFor(app.staticTexts["मुझे पानी चाहिए।"], timeout: 3)
    }

    func testQuickPhrasesPrepareForAnotherTranslationLanguage() {
        let app = launch(["-onboarded", "YES", "-stubTranslation", "ok", "-phraseLanguage", "es"])
        app.buttons["home.phrases"].tap()
        waitFor(app.staticTexts["Phrases are ready in Spanish."], timeout: 15)
        let translatedYes = app.buttons["[Spanish] Yes"]
        waitFor(translatedYes, timeout: 3)
        XCTAssertTrue(translatedYes.isEnabled)
    }

    func testQuickPhraseIsSpokenWithOneTap() {
        let app = launch()
        app.buttons["home.phrases"].tap()
        waitFor(app.staticTexts["Right now"])

        app.buttons["Please help me."].tap()
        waitFor(app.buttons["phrases.stop"], timeout: 3)
    }

    func testLookToChooseNarrowsSixteenPhrasesToOne() {
        let app = launch()
        app.buttons["home.phrases"].tap()
        app.buttons["Turn your head to choose"].tap()

        let left = app.buttons["look.left"]
        waitFor(left)
        for _ in 0..<4 {
            left.tap()
        }
        waitFor(app.buttons["Say it again"])
        XCTAssertTrue(app.staticTexts["Yes"].exists)

        app.buttons["Start over"].tap()
        waitFor(app.buttons["look.left"])
        app.buttons["Done"].tap()
        waitFor(app.staticTexts["Right now"])
    }

    func testTalkTogetherCanFaceEachOtherOrSitSideBySide() {
        let app = launch()
        app.buttons["home.talk"].tap()

        let flip = app.buttons["talk.flip"]
        waitFor(flip)
        XCTAssertEqual(flip.label, "Facing each other")
        attachScreenshot(app, named: "Talk together screen")
        flip.tap()
        XCTAssertEqual(flip.label, "Side by side")
        XCTAssertTrue(app.buttons["Talk"].exists)
    }

    func testTapAnywhereChoosesTheLitControl() {
        let app = launch(["-onboarded", "YES", "-control", "scanning", "-scanInterval", "30"])
        waitFor(app.buttons["home.speak"])
        sleep(2)

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        waitFor(app.navigationBars["Speak for me"])
        waitFor(app.buttons["Go back"])
    }

    func testHoldingThreeSecondsReturnsToTouch() {
        let app = launch(["-onboarded", "YES", "-control", "scanning", "-scanInterval", "30"])
        waitFor(app.buttons["home.speak"])
        sleep(2)

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).press(forDuration: 3.5)

        app.buttons["home.translate"].tap()
        waitFor(app.navigationBars["Translate"])
    }

    func testSettingsOffersEveryWayToControlBridge() {
        let app = launch()
        app.buttons["home.settings"].tap()
        app.buttons["How you control Bridge, Touch"].firstMatch.tap()

        waitFor(app.staticTexts["Touch"])
        XCTAssertTrue(app.staticTexts["Tap anywhere (switch scanning)"].exists)
        XCTAssertTrue(app.staticTexts["Head pointer"].exists)
    }

    func testHomePassesTheAccessibilityAudit() throws {
        let app = launch()
        waitFor(app.buttons["home.speak"])
        try audit(app, attachmentName: "Home")
    }

    func testPhrasesPassTheAccessibilityAudit() throws {
        let app = launch()
        app.buttons["home.phrases"].tap()
        waitFor(app.staticTexts["Right now"])
        try audit(app, attachmentName: "Quick phrases")
    }

    func testIPadHomeAndPhrasesWorkInLandscape() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("This layout check is for iPad.")
        }
        addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
        let app = launch()
        waitFor(app.buttons["home.phrases"])
        XCUIDevice.shared.orientation = .landscapeLeft
        app.buttons["home.phrases"].tap()
        attachScreenshot(app, named: "iPad landscape phrases")
        waitFor(app.staticTexts["Right now"])
        XCTAssertTrue(app.buttons["phrases.languagePicker"].isHittable)
        XCTAssertTrue(app.buttons["Turn your head to choose"].isHittable)
    }

    func testTranslateFailurePassesTheAccessibilityAudit() throws {
        let app = translateTyped("I need some water.", stub: "fail")
        waitFor(app.buttons["Say in English"])
        try audit(app, attachmentName: "Translate failure")
    }

    private func launchAtLargestText() -> XCUIApplication {
        launch(["-onboarded", "YES", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
    }

    func testHomeAtLargestTextPassesTheAudit() throws {
        let app = launchAtLargestText()
        waitFor(app.buttons["home.speak"])
        try audit(app, attachmentName: "Home AX5")
    }

    func testPhrasesAtLargestTextPassTheAudit() throws {
        let app = launchAtLargestText()
        app.buttons["home.phrases"].tap()
        waitFor(app.buttons["phrases.languagePicker"])
        try audit(app, attachmentName: "Quick phrases AX5")
    }

    func testSpeakAtLargestTextKeepsEveryControl() throws {
        let app = launchAtLargestText()
        app.buttons["home.speak"].tap()
        waitFor(app.buttons["Talk"])
        XCTAssertTrue(app.buttons["Type"].isHittable)
        XCTAssertTrue(app.buttons["Talk"].isHittable)
        try audit(app, attachmentName: "Speak AX5")
    }

    private func audit(_ app: XCUIApplication, attachmentName: String) throws {
        attachScreenshot(app, named: attachmentName)
        let tabs: Set<String> = ["Home", "Speak", "Translate", "Assist"]
        let screenHeight = app.frame.height
        let assistant = app.buttons["Open assistant"]
        let barTop = assistant.exists ? assistant.frame.minY - 6 : screenHeight
        try app.performAccessibilityAudit { issue in
            if issue.auditType == .contrast, let element = issue.element, !tabs.contains(element.label),
               element.frame.maxY > barTop {
                return true
            }
            if issue.auditType == .dynamicType, let element = issue.element, tabs.contains(element.label),
               element.frame.minY > screenHeight * 0.8 {
                return true
            }
            let element = issue.element.map { "\($0.elementType.rawValue) \"\($0.label)\" \($0.frame)" } ?? "no element"
            print("AUDIT ISSUE: \(issue.compactDescription) - \(element)")
            return false
        }
    }

    private func attachScreenshot(_ app: XCUIApplication, named attachmentName: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = attachmentName
        shot.lifetime = .keepAlways
        add(shot)
    }
}
