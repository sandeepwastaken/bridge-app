package org.congressionalappchallenge.bridge.platform

import android.content.Context
import android.speech.tts.TextToSpeech
import android.speech.tts.Voice
import org.congressionalappchallenge.bridge.data.BridgeLanguage
import java.util.Locale

class LocalSpeaker(context: Context) : TextToSpeech.OnInitListener {
    private val engine = TextToSpeech(context.applicationContext, this)
    private var ready = false

    override fun onInit(status: Int) {
        ready = status == TextToSpeech.SUCCESS
    }

    fun say(text: String, language: BridgeLanguage): String? {
        if (!ready) return "Speech is still starting. Try again in a moment."
        val locale = Locale.forLanguageTag(language.speechTag)
        val voice: Voice = engine.voices
            ?.filter { it.locale.language == locale.language && !it.isNetworkConnectionRequired }
            ?.maxByOrNull { it.quality }
            ?: return "No on-device ${language.englishName} voice is installed."

        engine.voice = voice
        engine.setSpeechRate(0.92f)
        val result = engine.speak(text, TextToSpeech.QUEUE_FLUSH, null, "bridge-speech")
        return if (result == TextToSpeech.ERROR) "Speech could not start." else null
    }

    fun stop() { engine.stop() }

    fun close() {
        engine.stop()
        engine.shutdown()
    }
}
