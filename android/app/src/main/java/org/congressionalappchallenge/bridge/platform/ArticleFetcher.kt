package org.congressionalappchallenge.bridge.platform

import java.net.HttpURLConnection
import java.net.URI
import java.io.ByteArrayOutputStream
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.congressionalappchallenge.bridge.data.ArticleText

object ArticleFetcher {
    suspend fun fetch(uri: URI): String = withContext(Dispatchers.IO) {
        require(ArticleText.link(uri.toString()) != null)
        var destination = uri
        repeat(6) {
            val connection = destination.toURL().openConnection() as HttpURLConnection
            try {
                connection.connectTimeout = 15_000
                connection.readTimeout = 15_000
                connection.instanceFollowRedirects = false
                connection.setRequestProperty("User-Agent", "Bridge article reader")
                val status = connection.responseCode
                if (status in setOf(301, 302, 303, 307, 308)) {
                    destination = destination.resolve(connection.getHeaderField("Location") ?: error("Missing redirect"))
                    require(ArticleText.link(destination.toString()) != null)
                } else {
                    require(status in 200..299)
                    val bytes = connection.inputStream.use { input ->
                        val output = ByteArrayOutputStream()
                        val buffer = ByteArray(8192)
                        while (true) {
                            val count = input.read(buffer)
                            if (count < 0) break
                            require(output.size() + count <= 2_000_000)
                            output.write(buffer, 0, count)
                        }
                        output.toByteArray()
                    }
                    val content = bytes.toString(Charsets.UTF_8)
                    val text = if (connection.contentType.orEmpty().startsWith("text/plain")) content.trim() else ArticleText.readable(content)
                    require(text.isNotBlank())
                    return@withContext text
                }
            } finally {
                connection.disconnect()
            }
        }
        error("Too many redirects")
    }
}
