package org.congressionalappchallenge.bridge

import org.congressionalappchallenge.bridge.data.ArticleText
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class ArticleTextTest {
    @Test fun acceptsOnlySingleWebLinks() {
        assertNotNull(ArticleText.link(" https://www.nps.gov/subjects/trails/types-of-trails.htm \n"))
        assertNull(ArticleText.link("Read https://example.com please"))
        assertNull(ArticleText.link("file:///etc/hosts"))
        assertNull(ArticleText.link("https://name:password@example.com"))
    }

    @Test fun extractsArticleWithoutNavigationAndPreservesNumbers() {
        val html = """
            <nav><p>This navigation text is long enough to be mistaken for a paragraph.</p></nav>
            <script><p>This script text must not appear in the article.</p></script>
            <article><h1>Your appointment</h1>
            <p>Please arrive at 10:<b>30</b> on Tuesday &amp; bring your insurance card.</p>
            <p>Please arrive at 10:<b>30</b> on Tuesday &amp; bring your insurance card.</p>
            <p>It&#8217;s important to bring ID.<br>Call &#x31;23 if you need help.</p></article>
            <footer><p>This footer text is long enough to be mistaken for a paragraph.</p></footer>
        """.trimIndent()
        assertEquals("Your appointment\n\nPlease arrive at 10:30 on Tuesday & bring your insurance card.\n\nIt’s important to bring ID. Call 123 if you need help.", ArticleText.readable(html))
    }

    @Test fun ignoresInvalidNumericEntitiesWithoutCrashing() {
        assertEquals("This paragraph has an invalid entity &#999999999999; and stays readable.", ArticleText.readable("<p>This paragraph has an invalid entity &#999999999999; and stays readable.</p>"))
    }
}
