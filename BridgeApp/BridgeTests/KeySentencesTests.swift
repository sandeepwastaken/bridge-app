import Testing
@testable import Bridge

struct KeySentencesTests {
    private let letter = """
    Your appointment with Dr. Rao is on Tuesday at 10:30. Please bring your insurance card. \
    The weather has been lovely this week. Parking is free behind the clinic. \
    If you cannot come to the appointment, call the clinic before Monday. We look forward to seeing you.
    """

    @Test func shortTextIsReturnedWhole() {
        #expect(KeySentences.extract(from: "One thing. Two things.") == ["One thing.", "Two things."])
    }

    @Test func blankTextHasNoSentences() {
        #expect(KeySentences.extract(from: "  \n ").isEmpty)
    }

    @Test func sentencesAreCopiedWordForWordInTheirOriginalOrder() {
        let picked = KeySentences.extract(from: letter)
        #expect(picked.count == 3)
        for sentence in picked { #expect(letter.contains(sentence)) }
        let positions = picked.compactMap { letter.range(of: $0)?.lowerBound }
        #expect(positions == positions.sorted())
    }

    @Test func sentencesThatShareTheMainTopicAreChosen() {
        let picked = KeySentences.extract(from: letter)
        #expect(picked.contains { $0.contains("appointment with Dr. Rao") })
        #expect(picked.contains { $0.contains("cannot come to the appointment") })
        #expect(!picked.contains { $0.contains("weather") })
    }
}
