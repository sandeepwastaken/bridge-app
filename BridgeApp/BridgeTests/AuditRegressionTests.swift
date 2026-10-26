import Testing
@testable import Bridge

@MainActor
struct TranslationHonestyTests {
    @Test func aTranslationThatNeverAnswersTimesOut() async {
        let model = makeTalkModel(translator: Translator(timeout: .milliseconds(200)))
        model.mode = .translate
        await model.useTyped("I need some water.")

        #expect(model.phase == .review)
        #expect(model.current?.translationFailed == true)
        #expect(model.current?.translation == nil)
    }

    @Test func aFailedTranslationIsSpokenInTheOriginalLanguage() async {
        let model = makeTalkModel(translator: Translator(stub: { _, _, _ in throw TranslationFailure.failed }))
        model.mode = .translate
        await model.useTyped("I need some water.")

        #expect(model.current?.translationFailed == true)
        #expect(model.willSpeakIn == .english)
    }

    @Test func aSuccessfulTranslationIsSpokenInTheListenersLanguage() async {
        let model = makeTalkModel(translator: Translator(stub: { _, _, _ in "मुझे पानी चाहिए।" }))
        model.mode = .translate
        await model.useTyped("I need some water.")

        #expect(model.current?.translation == "मुझे पानी चाहिए।")
        #expect(model.willSpeakIn == .hindi)
        #expect(model.phase == .review)
    }

    @Test func talkTogetherDoesNotSpeakAnUntranslatedTurn() async {
        let model = makeTalkModel(translator: Translator(stub: { _, _, _ in throw TranslationFailure.failed }))
        model.settings.autoSpeakTurns = true
        model.mode = .conversation
        await model.useTyped("Where is the bathroom?")

        #expect(model.phase == .review)
        #expect(model.current?.wasSpoken == false)
    }

    @Test func retryingATranslationCanSucceed() async {
        var attempts = 0
        let model = makeTalkModel(translator: Translator(stub: { _, _, _ in
            attempts += 1
            if attempts == 1 { throw TranslationFailure.failed }
            return "धन्यवाद।"
        }))
        model.mode = .translate
        await model.useTyped("Thank you.")
        #expect(model.current?.translationFailed == true)

        await model.retryTranslation()
        #expect(model.current?.translation == "धन्यवाद।")
        #expect(model.current?.translationFailed == false)
        #expect(model.phase == .review)
    }
}

@MainActor
struct LanguageSettingTests {
    @Test func theTwoLanguagesAreAlwaysDifferent() {
        let settings = AppSettings(defaults: isolatedDefaults())
        settings.myLanguage = .hindi
        #expect(settings.partnerLanguage == .english)
        settings.partnerLanguage = .hindi
        #expect(settings.myLanguage == .english)
    }

    @Test func storedEqualLanguagesAreRepairedOnLaunch() {
        let defaults = isolatedDefaults()
        defaults.set("en-US", forKey: "myLanguage")
        defaults.set("en-US", forKey: "partnerLanguage")
        let settings = AppSettings(defaults: defaults)
        #expect(settings.myLanguage != settings.partnerLanguage)
    }

    @Test func phrasesStartInMyLanguage() {
        let defaults = isolatedDefaults()
        defaults.set("hi-IN", forKey: "myLanguage")
        #expect(AppSettings(defaults: defaults).phraseLanguage == .hindi)
    }
}

struct PhraseLanguageTests {
    @Test func myOwnPhraseIsAlwaysSaidAsWritten() {
        let phrase = QuickPhrase(id: "x", english: "दीदी को बुलाओ", hindi: "दीदी को बुलाओ",
                                 symbol: "star.fill", onlyIn: .hindi)
        #expect(phrase.spokenLanguage(for: .english) == .hindi)
        #expect(phrase.text(in: .english) == "दीदी को बुलाओ")
    }

    @Test func builtInPhrasesCanBeSaidInEitherLanguage() {
        let water = PhraseBook.groups.flatMap(\.phrases).first { $0.id == "water" }!
        #expect(water.spokenLanguage(for: .english) == .english)
        #expect(water.spokenLanguage(for: .hindi) == .hindi)
        #expect(water.text(in: .hindi) == "मुझे पानी चाहिए।")
    }

    @Test func hindiPhrasesAvoidGenderedFirstPersonVerbs() {
        let gendered = ["गई हूँ", "गया हूँ", "चाहती", "चाहता", "रही हूँ", "रहा हूँ"]
        for phrase in PhraseBook.groups.flatMap(\.phrases) {
            for form in gendered {
                #expect(!phrase.hindi.contains(form), "\(phrase.id): \(phrase.hindi)")
            }
        }
    }
}
