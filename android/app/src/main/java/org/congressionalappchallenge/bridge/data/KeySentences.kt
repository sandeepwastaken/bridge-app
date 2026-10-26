package org.congressionalappchallenge.bridge.data

import java.text.BreakIterator
import java.util.Locale
import kotlin.math.sqrt

object KeySentences {
    private val commonWords = setOf(
        "the", "and", "for", "are", "but", "not", "you", "your", "with", "this", "that", "from", "they", "have",
        "has", "had", "was", "were", "will", "would", "can", "could", "should", "there", "their", "them", "then",
        "than", "what", "when", "where", "which", "who", "how", "all", "any", "our", "its", "his", "her", "she",
        "him", "been", "into", "about", "also", "just", "more", "some", "such", "only", "over", "very", "may",
    )

    fun extract(text: String, limit: Int = 3, locale: Locale = Locale.getDefault()): List<String> {
        val sentences = split(text, BreakIterator.getSentenceInstance(locale))
        if (sentences.size <= limit) return sentences
        val words = sentences.map { sentence ->
            split(sentence, BreakIterator.getWordInstance(locale))
                .map { it.lowercase(locale) }
                .filter { word -> word.length > 2 && word.any(Char::isLetterOrDigit) && word !in commonWords }
        }
        val frequency = HashMap<String, Int>()
        words.forEach { list -> list.toSet().forEach { frequency[it] = (frequency[it] ?: 0) + 1 } }
        val scores = words.mapIndexed { index, list ->
            if (list.isEmpty()) 0.0
            else list.sumOf { (frequency[it] ?: 0).toDouble() } / sqrt(list.size.toDouble()) + if (index == 0) 0.5 else 0.0
        }
        return scores.indices
            .sortedWith(compareByDescending<Int> { scores[it] }.thenBy { it })
            .take(limit)
            .sorted()
            .map { sentences[it] }
    }

    private fun split(text: String, iterator: BreakIterator): List<String> {
        iterator.setText(text)
        val parts = mutableListOf<String>()
        var start = iterator.first()
        var end = iterator.next()
        while (end != BreakIterator.DONE) {
            val part = text.substring(start, end).trim()
            if (part.isNotEmpty()) parts += part
            start = end
            end = iterator.next()
        }
        return parts
    }
}
