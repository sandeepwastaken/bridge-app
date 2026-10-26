import Foundation
import SwiftUI
import Testing
@testable import Bridge

struct LanguageTests {
    @Test func eachLanguageKnowsItsPartner() {
        #expect(Language.english.other == .hindi)
        #expect(Language.hindi.other == .english)
    }

    @Test func namesAreWrittenInTheirOwnScript() {
        #expect(Language.hindi.nativeName == "हिन्दी")
        #expect(Language.hindi.englishName == "Hindi")
        #expect(Language.hindi.locale.identifier == "hi-IN")
    }

    @Test func languageCatalogIsBroadAndKeepsStoredLanguageCodes() throws {
        #expect(Language.allCases.count >= 59)
        #expect(Language(rawValue: "en-US") == .english)
        #expect(Language(rawValue: "hi-IN") == .hindi)
        let encoded = try JSONEncoder().encode(Language.hindi)
        #expect(String(data: encoded, encoding: .utf8) == "\"hi-IN\"")
        #expect(try JSONDecoder().decode(Language.self, from: encoded) == .hindi)
    }

    @Test func devanagariIsDetected() {
        #expect("मुझे पानी चाहिए".containsDevanagari)
        #expect(!"I need water".containsDevanagari)
        #expect("Nani · नानी".containsDevanagari)
    }
}

struct MessageTests {
    @Test func theTranslationIsWhatGetsSpoken() {
        var message = Message(mode: .translate, sourceLanguage: .english, text: "Hello", targetLanguage: .hindi)
        #expect(message.spokenText == "Hello")
        #expect(message.spokenLanguage == .english)

        message.translation = "नमस्ते"
        #expect(message.spokenText == "नमस्ते")
        #expect(message.spokenLanguage == .hindi)
    }

    @Test func medianOfLatencies() {
        #expect(SessionNumbers.median([]) == nil)
        #expect(SessionNumbers.median([900, 100, 400]) == 400)
    }
}

@MainActor
struct SettingsTests {
    @Test func defaultsSuitAFirstTimeUser() {
        let settings = AppSettings(defaults: isolatedDefaults())
        #expect(settings.control == .touch)
        #expect(settings.onboarded == false)
        #expect(settings.myLanguage == .english)
        #expect(settings.partnerLanguage == .hindi)
        #expect(settings.textSize == .system)
        #expect(!settings.keepHistory)
        #expect(!settings.autoSpeakTurns)
        #expect(settings.scanInterval == 1.6)
        #expect(settings.dwellTime == 1.2)
    }

    @Test func choicesAreRememberedAcrossLaunches() {
        let defaults = isolatedDefaults()
        let first = AppSettings(defaults: defaults)
        first.control = .scanning
        first.headSelect = .openMouth
        first.textSize = .extraLarge
        first.partnerName = "Nani"

        let again = AppSettings(defaults: defaults)
        #expect(again.control == .scanning)
        #expect(again.headSelect == .openMouth)
        #expect(again.textSize == .extraLarge)
        #expect(again.partnerName == "Nani")
    }

    @Test func textSizeCanOnlyGrow() {
        #expect(TextSizeBoost.system.range.lowerBound == .xSmall)
        #expect(TextSizeBoost.large.range.lowerBound == .xxxLarge)
        #expect(TextSizeBoost.extraLarge.range.lowerBound == .accessibility2)
        for boost in TextSizeBoost.allCases {
            #expect(boost.range.upperBound == .accessibility5)
        }
    }
}

struct PhraseBookTests {
    @Test func lookToChooseOffersSixteenPhrasesSoFourTurnsReachAny() {
        #expect(PhraseBook.lookToChoose.count == 16)
    }

    @Test func everyPhraseHasBothLanguagesAndAUniqueID() {
        let all = PhraseBook.groups.flatMap(\.phrases)
        #expect(Set(all.map(\.id)).count == all.count)
        for phrase in all {
            #expect(!phrase.english.isEmpty)
            #expect(phrase.hindi.containsDevanagari, "\(phrase.id) needs Hindi text")
        }
    }

    @Test func yesAndNoComeFirst() {
        #expect(PhraseBook.groups[0].phrases.prefix(2).map(\.id) == ["yes", "no"])
    }
}

@MainActor
struct HighlightTests {
    @Test func uncertainWordsBecomeTappableLinks() throws {
        let message = Message(mode: .speak, sourceLanguage: .english,
                              text: "Anika is coming on Sunday.", uncertainWords: ["sunday"])
        let attributed = SpeakView.attributed(message)

        let links = attributed.runs.compactMap(\.link)
        let link = try #require(links.first)
        #expect(links.count == 1)
        #expect(link.scheme == "bridge-fix")
        #expect(URLComponents(url: link, resolvingAgainstBaseURL: false)?.queryItems?.first?.value == "Sunday")
        #expect(String(attributed.characters).contains("Sunday"))
    }

    @Test func certainTextHasNoLinks() {
        let message = Message(mode: .speak, sourceLanguage: .english, text: "Hello there.")
        #expect(SpeakView.attributed(message).runs.allSatisfy { $0.link == nil })
    }

    @Test func theWordBeingSpokenIsHighlighted() {
        let message = Message(mode: .speak, sourceLanguage: .english, text: "Hello there.")
        let attributed = SpeakView.attributed(message, spoken: NSRange(location: 6, length: 5))
        let highlighted = attributed.runs.filter { $0.backgroundColor != nil }
        #expect(highlighted.count == 1)
        if let run = highlighted.first {
            #expect(String(attributed[run.range].characters) == "there")
        }
    }
}
