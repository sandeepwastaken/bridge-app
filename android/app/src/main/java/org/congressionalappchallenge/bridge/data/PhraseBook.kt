package org.congressionalappchallenge.bridge.data

data class BridgePhrase(
    val id: String,
    val english: String,
    val hindi: String,
    val symbol: String,
) {
    fun text(language: BridgeLanguage): String = when (language.tag) {
        "en" -> english
        "hi" -> hindi
        else -> english
    }
}

data class PhraseGroup(val title: String, val phrases: List<BridgePhrase>)

object PhraseBook {
    val groups = listOf(
        PhraseGroup("Right now", listOf(
            BridgePhrase("yes", "Yes", "हाँ", "✓"),
            BridgePhrase("no", "No", "नहीं", "×"),
            BridgePhrase("help", "Please help me.", "कृपया मेरी मदद करें।", "✋"),
            BridgePhrase("wait", "Please wait a moment.", "कृपया थोड़ा रुकिए।", "◷"),
            BridgePhrase("slow", "Please speak slowly.", "कृपया धीरे बोलिए।", "🐢"),
            BridgePhrase("repeat", "Could you say that again?", "क्या आप फिर से कहेंगे?", "↶"),
            BridgePhrase("thanks", "Thank you.", "धन्यवाद।", "♥"),
            BridgePhrase("understand", "I don't understand.", "मुझे समझ नहीं आया।", "?"),
        )),
        PhraseGroup("I need", listOf(
            BridgePhrase("water", "I need some water.", "मुझे पानी चाहिए।", "●"),
            BridgePhrase("bathroom", "I need to use the bathroom.", "मुझे बाथरूम जाना है।", "⌂"),
            BridgePhrase("medicine", "It's time for my medicine.", "मेरी दवा का समय हो गया है।", "+"),
            BridgePhrase("food", "I'm hungry.", "मुझे भूख लगी है।", "◒"),
            BridgePhrase("glasses", "Where are my glasses?", "मेरा चश्मा कहाँ है?", "◉"),
            BridgePhrase("rest", "I'd like to lie down.", "मुझे लेटना है।", "☾"),
            BridgePhrase("family", "Please call my family.", "कृपया मेरे परिवार को फ़ोन करें।", "⌕"),
            BridgePhrase("cold", "I'm feeling cold.", "मुझे ठंड लग रही है।", "❄"),
        )),
    )

    val all: List<BridgePhrase> = groups.flatMap(PhraseGroup::phrases)
}
