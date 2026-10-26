import Testing
@testable import Bridge

struct WordDiffTests {
    @Test func singleWordFixIsASubstitution() {
        let diff = WordDiff(from: "Annika is coming on Sunday.", to: "Anika is coming on Sunday.")
        #expect(diff.substitutions == [Replacement(heard: "Annika", saved: "Anika")])
        #expect(diff.changedCount == 1)
    }

    @Test func caseAndPunctuationChangesAreIgnored() {
        let diff = WordDiff(from: "anika is here", to: "Anika is here!")
        #expect(diff.substitutions.isEmpty)
        #expect(diff.changedCount == 0)
    }

    @Test func twoWordsBecomingOneIsNotRemembered() {
        let diff = WordDiff(from: "bring my blue car again", to: "bring my blue cardigan")
        #expect(diff.substitutions.isEmpty)
        #expect(diff.changedCount == 2)
    }

    @Test func severalSeparateFixesAreAllFound() {
        let diff = WordDiff(from: "Monica and Arjoon are here", to: "Anika and Arjun are here")
        #expect(diff.substitutions == [
            Replacement(heard: "Monica", saved: "Anika"),
            Replacement(heard: "Arjoon", saved: "Arjun"),
        ])
    }

    @Test func emptyOriginalCountsAsAChange() {
        let diff = WordDiff(from: "", to: "hello")
        #expect(diff.changedCount == 1)
        #expect(diff.substitutions.isEmpty)
    }

    @Test func identicalTextHasNoChanges() {
        let diff = WordDiff(from: "Please help me.", to: "Please help me.")
        #expect(diff.changedCount == 0)
    }
}
