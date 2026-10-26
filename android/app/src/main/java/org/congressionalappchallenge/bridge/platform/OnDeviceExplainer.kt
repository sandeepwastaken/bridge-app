package org.congressionalappchallenge.bridge.platform

import com.google.mlkit.genai.common.DownloadStatus
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.prompt.GenerativeModel
import org.congressionalappchallenge.bridge.data.BridgeLanguage

class OnDeviceExplainer : AutoCloseable {
    enum class Status { Ready, NeedsDownload, Downloading, Unavailable }

    private var client: GenerativeModel? = null
    private val model: GenerativeModel
        get() = client ?: Generation.getClient().also { client = it }

    suspend fun status(): Status = try {
        when (model.checkStatus()) {
            FeatureStatus.AVAILABLE -> Status.Ready
            FeatureStatus.DOWNLOADABLE -> Status.NeedsDownload
            FeatureStatus.DOWNLOADING -> Status.Downloading
            else -> Status.Unavailable
        }
    } catch (_: Exception) {
        Status.Unavailable
    }

    suspend fun download(): Boolean {
        model.download().collect { status ->
            if (status is DownloadStatus.DownloadFailed) throw status.e
        }
        return status() == Status.Ready
    }

    suspend fun explain(text: String, language: BridgeLanguage): String =
        model.generateContent(prompt(text, language)).candidates.firstOrNull()?.text?.trim().orEmpty()

    override fun close() {
        client?.close()
        client = null
    }

    companion object {
        fun prompt(text: String, language: BridgeLanguage): String =
            "You help someone who finds reading hard understand a piece of text. " +
                "Explain it in ${language.englishName} using short, plain sentences, no more than five. " +
                "Keep every name, number, date, time and amount exactly as written. " +
                "If the text asks the reader to do something, say clearly what it asks and by when. " +
                "Do not add advice, opinions or facts that are not in the text. " +
                "If something in the text is unclear, say that it is unclear instead of guessing.\n\n" +
                "Text:\n$text"
    }
}
