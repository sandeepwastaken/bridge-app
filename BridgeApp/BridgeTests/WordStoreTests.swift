import Foundation
import Testing
@testable import Bridge

@MainActor
struct WordStoreTests {
    @Test func rememberingACorrectionCreatesAPersonEntry() throws {
        let store = WordStore(fileName: nil)
        store.remember(saved: "Anika", heard: "Annika", language: .english)

        let entry = try #require(store.entries.first)
        #expect(entry.text == "Anika")
        #expect(entry.kind == .person, "Capitalized words are saved as people")
        #expect(entry.misheard == ["Annika"])
        #expect(entry.fixesBeforeSaving == 1)
    }

    @Test func rememberingAgainAddsTheMisheardFormOnce() {
        let store = WordStore(fileName: nil)
        store.remember(saved: "Anika", heard: "Annika", language: .english)
        store.remember(saved: "Anika", heard: "Monica", language: .english)
        store.remember(saved: "anika", heard: "monica", language: .english)

        #expect(store.entries.count == 1)
        #expect(store.entries[0].misheard == ["Annika", "Monica"])
        #expect(store.entries[0].fixesSinceSaving == 2)
    }

    @Test func savedSpellingReplacesWholeWordsAndReportsIt() {
        let store = WordStore(fileName: nil)
        store.remember(saved: "Anika", heard: "Annika", language: .english)

        let (text, replacements) = store.applySavedSpellings(to: "annika is here. Annika!", language: .english)
        #expect(text == "Anika is here. Anika!")
        #expect(replacements == [Replacement(heard: "Annika", saved: "Anika")])
    }

    @Test func savedSpellingNeverChangesPartsOfOtherWords() {
        let store = WordStore(fileName: nil)
        store.remember(saved: "Anika", heard: "Annika", language: .english)

        let (text, replacements) = store.applySavedSpellings(to: "Annikas toy", language: .english)
        #expect(text == "Annikas toy")
        #expect(replacements.isEmpty)
    }

    @Test func savedSpellingOnlyAppliesToItsOwnLanguage() {
        let store = WordStore(fileName: nil)
        store.remember(saved: "Anika", heard: "Annika", language: .english)

        let (text, _) = store.applySavedSpellings(to: "Annika", language: .hindi)
        #expect(text == "Annika")
    }

    @Test func contextualStringsAreMostUsedFirstAndSkipPhrases() {
        let store = WordStore(fileName: nil, entries: [
            WordEntry(text: "Edison", kind: .place, language: .english, uses: 1),
            WordEntry(text: "Anika", kind: .person, language: .english, uses: 9),
            WordEntry(text: "Please help me.", kind: .phrase, language: .english, uses: 50),
            WordEntry(text: "नानी", kind: .person, language: .hindi, uses: 3),
        ])
        #expect(store.contextualStrings(for: .english) == ["Anika", "Edison"])
        #expect(store.contextualStrings(for: .hindi) == ["नानी"])
    }

    @Test func usesAreCountedWhenSavedWordsAreSaid() {
        let store = WordStore(fileName: nil, entries: [WordEntry(text: "Anika", kind: .person, language: .english)])
        store.recordUses(in: "Is Anika home?")
        store.recordUses(in: "No one is here.")
        #expect(store.entries[0].uses == 1)
    }

    @Test func entriesOfAKindAreSortedAlphabetically() {
        let store = WordStore(fileName: nil, entries: [
            WordEntry(text: "zara", kind: .person, language: .english),
            WordEntry(text: "Arjun", kind: .person, language: .english),
            WordEntry(text: "Edison", kind: .place, language: .english),
        ])
        #expect(store.entries(of: .person).map(\.text) == ["Arjun", "zara"])
    }

    @Test func wordsSurviveARestart() throws {
        let file = "words-test-\(UUID().uuidString).json"
        defer { LocalFile.delete(file) }

        let first = WordStore(fileName: file)
        first.upsert(WordEntry(text: "Dr. Mehta", kind: .person, note: "Heart doctor", language: .english))

        let reloaded = WordStore(fileName: file)
        let entry = try #require(reloaded.entries.first)
        #expect(entry.text == "Dr. Mehta")
        #expect(entry.note == "Heart doctor")
    }

    @Test func deleteAllEmptiesTheList() {
        let store = WordStore(fileName: nil, entries: [WordEntry(text: "Anika", kind: .person, language: .english)])
        store.deleteAll()
        #expect(store.entries.isEmpty)
    }
}
