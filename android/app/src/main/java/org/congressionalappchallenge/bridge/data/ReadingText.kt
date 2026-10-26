package org.congressionalappchallenge.bridge.data

object ReadingText {
    fun paragraphs(source: String): List<String> = source
        .replace("\r\n", "\n").replace("\r", "\n")
        .split(Regex("\n[\\t ]*\n"))
        .map { it.trim() }.filter { it.isNotEmpty() }
}
