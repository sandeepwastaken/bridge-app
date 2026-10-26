package org.congressionalappchallenge.bridge.data

import java.net.URI

object ArticleText {
    fun link(text: String): URI? {
        val value = text.trim()
        if (value.isEmpty() || value.any(Char::isWhitespace)) return null
        return runCatching { URI(value) }.getOrNull()?.takeIf {
            it.scheme?.lowercase() in setOf("http", "https") && !it.host.isNullOrBlank() && it.userInfo == null
        }
    }

    fun readable(html: String): String {
        val options = setOf(RegexOption.IGNORE_CASE, RegexOption.DOT_MATCHES_ALL)
        var body = html
        for (tag in listOf("script", "style", "noscript", "nav", "header", "footer", "aside", "form", "svg")) {
            body = body.replace(Regex("<$tag\\b[^>]*>.*?</$tag\\s*>", options), " ")
        }
        body = Regex("<article\\b[^>]*>.*?</article\\s*>", options).find(body)?.value ?: body
        return Regex("<(h[1-3]|p|li)\\b[^>]*>(.*?)</\\1\\s*>", options).findAll(body).mapNotNull { match ->
            val value = decode(match.groupValues[2].replace(Regex("<br\\s*/?>", RegexOption.IGNORE_CASE), " ").replace(Regex("<[^>]+>"), ""))
                .replace(Regex("\\s+"), " ").trim()
            value.takeIf { it.length >= if (match.groupValues[1].startsWith("h", true)) 3 else 40 }
        }.distinct().joinToString("\n\n")
    }

    private fun decode(value: String): String {
        val named = mapOf("amp" to "&", "quot" to "\"", "apos" to "'", "lt" to "<", "gt" to ">", "nbsp" to " ",
            "rsquo" to "’", "lsquo" to "‘", "rdquo" to "”", "ldquo" to "“", "ndash" to "–", "mdash" to "-", "hellip" to "…")
        return Regex("&(#(?:[xX][0-9a-fA-F]+|[0-9]+)|[a-zA-Z]+);").replace(value) { match ->
            val entity = match.groupValues[1]
            if (!entity.startsWith("#")) named[entity] ?: match.value
            else {
                val hex = entity.startsWith("#x", true)
                val code = entity.drop(if (hex) 2 else 1).toIntOrNull(if (hex) 16 else 10)
                if (code != null && Character.isValidCodePoint(code) && code !in 0xD800..0xDFFF) String(Character.toChars(code))
                else match.value
            }
        }
    }
}
