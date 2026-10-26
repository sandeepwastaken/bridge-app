package org.congressionalappchallenge.bridge.platform

import com.google.android.gms.tasks.Task
import com.google.mlkit.common.model.DownloadConditions
import com.google.mlkit.nl.translate.Translation
import com.google.mlkit.nl.translate.TranslatorOptions
import kotlinx.coroutines.suspendCancellableCoroutine
import org.congressionalappchallenge.bridge.data.BridgeLanguage
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

class OnDeviceTranslator {
    suspend fun translate(
        text: String,
        from: BridgeLanguage,
        to: BridgeLanguage,
    ): String = translateMany(listOf(text), from, to).single()

    suspend fun translateMany(
        texts: List<String>,
        from: BridgeLanguage,
        to: BridgeLanguage,
    ): List<String> {
        require(from != to) { "Choose two different languages." }
        val source = code(from)
        val target = code(to)
        val translator = Translation.getClient(
            TranslatorOptions.Builder()
                .setSourceLanguage(source)
                .setTargetLanguage(target)
                .build(),
        )
        return try {
            translator.downloadModelIfNeeded(
                DownloadConditions.Builder().requireWifi().build(),
            ).awaitTask()
            texts.map { translator.translate(it).awaitTask() }
        } finally {
            translator.close()
        }
    }

    private fun code(language: BridgeLanguage): String = language.translationCode
}

private suspend fun <T> Task<T>.awaitTask(): T = suspendCancellableCoroutine { continuation ->
    addOnSuccessListener { value ->
        if (continuation.isActive) continuation.resume(value)
    }
    addOnFailureListener { error ->
        if (continuation.isActive) continuation.resumeWithException(error)
    }
    addOnCanceledListener {
        if (continuation.isActive) continuation.cancel()
    }
}
