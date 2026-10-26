package org.congressionalappchallenge.bridge

import java.util.Locale
import org.congressionalappchallenge.bridge.data.KeySentences
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class KeySentencesTest {
    private val letter = "Your appointment with Doctor Rao is on Tuesday at 10:30. Please bring your insurance card. " +
        "The weather has been lovely this week. Parking is free behind the clinic. " +
        "If you cannot come to the appointment, call the clinic before Monday. We look forward to seeing you."

    private fun extract(text: String) = KeySentences.extract(text, locale = Locale.ENGLISH)

    @Test fun shortTextIsReturnedWhole() {
        assertEquals(listOf("One thing.", "Two things."), extract("One thing. Two things."))
    }

    @Test fun blankTextHasNoSentences() {
        assertTrue(extract("  \n ").isEmpty())
    }

    @Test fun sentencesAreCopiedWordForWordInTheirOriginalOrder() {
        val picked = extract(letter)
        assertEquals(3, picked.size)
        picked.forEach { assertTrue(letter.contains(it)) }
        val positions = picked.map { letter.indexOf(it) }
        assertEquals(positions.sorted(), positions)
    }

    @Test fun sentencesThatShareTheMainTopicAreChosen() {
        val picked = extract(letter)
        assertTrue(picked.any { it.contains("appointment with Doctor Rao") })
        assertTrue(picked.any { it.contains("cannot come to the appointment") })
        assertFalse(picked.any { it.contains("weather") })
    }
}
