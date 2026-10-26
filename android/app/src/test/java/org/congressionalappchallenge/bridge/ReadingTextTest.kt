package org.congressionalappchallenge.bridge

import org.congressionalappchallenge.bridge.data.ReadingText
import org.junit.Assert.assertEquals
import org.junit.Test

class ReadingTextTest {
    @Test fun blankTextHasNoParagraphs() {
        assertEquals(emptyList<String>(), ReadingText.paragraphs(" \n\t\n"))
    }
    @Test fun preservesNumbersScriptsAndLineBreaks() {
        assertEquals(listOf("Appointment: 10:30\nBring ID.", "नमस्ते।", "తెలుగు."),
            ReadingText.paragraphs("Appointment: 10:30\r\nBring ID.\r\n\r\nनमस्ते।\n\nతెలుగు."))
    }
    @Test fun ignoresRepeatedBlankParagraphs() {
        assertEquals(listOf("One", "Two"), ReadingText.paragraphs("\n\nOne\n \n\t\nTwo\n\n"))
    }
}
