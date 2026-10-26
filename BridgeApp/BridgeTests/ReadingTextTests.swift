import Foundation
import Testing
@testable import Bridge

struct ReadingTextTests {
    @Test func blankTextHasNoParagraphs() {
        #expect(ReadingText.paragraphs(in: " \n\t\n").isEmpty)
    }

    @Test func preservesNumbersScriptsAndSingleLineBreaks() {
        let source = "Appointment: 10:30\r\nBring ID.\r\n\r\nनमस्ते।\n\nతెలుగు."
        #expect(ReadingText.paragraphs(in: source) == ["Appointment: 10:30\nBring ID.", "नमस्ते।", "తెలుగు."])
    }

    @Test func ignoresRepeatedBlankParagraphs() {
        #expect(ReadingText.paragraphs(in: "\n\nOne\n \n\t\nTwo\n\n") == ["One", "Two"])
    }
}

@MainActor
struct ConsentDefaultTests {
    @Test func newInstallDoesNotKeepOrAutomaticallySpeakWords() {
        let settings = AppSettings(defaults: isolatedDefaults())
        #expect(!settings.keepHistory)
        #expect(!settings.autoSpeakTurns)
    }

    @Test func explicitChoicesSurviveAnUpgrade() {
        let defaults = isolatedDefaults()
        defaults.set(true, forKey: "keepHistory")
        defaults.set(true, forKey: "autoSpeakTurns")
        let settings = AppSettings(defaults: defaults)
        #expect(settings.keepHistory)
        #expect(settings.autoSpeakTurns)
    }
}
