import Testing
@testable import Bridge

@MainActor
struct TalkModelTests {
    @Test func typedWordsGoStraightToReview() async {
        let model = makeTalkModel()
        await model.useTyped("  Please bring my glasses.  ")

        #expect(model.phase == .review)
        #expect(model.current?.text == "Please bring my glasses.")
        #expect(model.current?.wasTyped == true)
        #expect(model.current?.translation == nil)
    }

    @Test func emptyTypingIsIgnored() async {
        let model = makeTalkModel()
        await model.useTyped("   ")
        #expect(model.phase == .idle)
        #expect(model.current == nil)
    }

    @Test func newLeafMovesTheMessageIntoHistory() async {
        let model = makeTalkModel()
        await model.useTyped("Good morning.")
        model.newLeaf()

        #expect(model.current == nil)
        #expect(model.phase == .idle)
        #expect(model.history.messages.map(\.text) == ["Good morning."])
    }

    @Test func historyIsNotKeptWhenSwitchedOff() async {
        let model = makeTalkModel(keepHistory: false)
        await model.useTyped("Good morning.")
        model.newLeaf()
        #expect(model.history.messages.isEmpty)
    }

    @Test func typingAgainTearsOffThePreviousMessage() async {
        let model = makeTalkModel()
        await model.useTyped("First.")
        await model.useTyped("Second.")
        #expect(model.current?.text == "Second.")
        #expect(model.history.messages.map(\.text) == ["First."])
    }

    @Test func fixingWordsUpdatesTextRemembersAndCounts() async {
        let model = makeTalkModel()
        await model.useTyped("Annika is here")
        await model.applyFix(text: "Anika is here",
                             remember: [Replacement(heard: "Annika", saved: "Anika")],
                             wordsChanged: 1)

        #expect(model.current?.text == "Anika is here")
        #expect(model.current?.uncertainWords.isEmpty == true)
        #expect(model.phase == .review)
        #expect(model.words.contains("Anika"))
        #expect(model.metrics.numbers.fixedBeforeSpeaking == 1)
        #expect(model.metrics.numbers.wordsChanged == 1)
    }

    @Test func aFixThatChangesNothingIsIgnored() async {
        let model = makeTalkModel()
        await model.useTyped("Hello")
        await model.applyFix(text: "Hello", remember: [], wordsChanged: 0)
        #expect(model.metrics.numbers.fixedBeforeSpeaking == 0)
    }

    @Test func changingModeClearsTheScreen() async {
        let model = makeTalkModel()
        await model.useTyped("Hello")
        model.mode = .translate
        #expect(model.current == nil)
        #expect(model.phase == .idle)
        #expect(model.history.messages.count == 1)
    }

    @Test func languagesFollowTheModeAndTheSpeaker() {
        let model = makeTalkModel()
        model.settings.myLanguage = .english
        model.settings.partnerLanguage = .hindi

        model.mode = .speak
        #expect(model.sourceLanguage == .english)
        #expect(model.targetLanguage == nil)

        model.mode = .translate
        #expect(model.sourceLanguage == .english)
        #expect(model.targetLanguage == .hindi)

        model.mode = .conversation
        model.activeSide = .partner
        #expect(model.sourceLanguage == .hindi)
        #expect(model.targetLanguage == .english)
    }

    @Test func partnerIsCalledThemUntilNamed() {
        let model = makeTalkModel()
        #expect(model.name(for: .partner) == "Them")
        model.settings.partnerName = "  Nani "
        #expect(model.name(for: .partner) == "Nani")
        #expect(model.name(for: .me) == "Me")
    }

    @Test func failureMessagesNeverBlameThePerson() {
        let failures: [TalkModel.Failure] = [.noSpeech, .permissionDenied, .onDeviceUnavailable(.hindi),
                                             .recognizerUnavailable(.english), .audio]
        for failure in failures {
            #expect(!failure.message.lowercased().contains("error"))
            #expect(!failure.message.lowercased().contains("failed"))
        }
        #expect(TalkModel.Failure.onDeviceUnavailable(.hindi).message.contains("Hindi"))
    }
}
