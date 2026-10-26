package org.congressionalappchallenge.bridge.data

import com.google.mlkit.nl.translate.TranslateLanguage
import java.util.Locale

data class BridgeLanguage(val tag: String) {
    val locale: Locale = Locale.forLanguageTag(tag)
    val nativeName: String = locale.getDisplayLanguage(locale)
    val englishName: String = locale.getDisplayLanguage(Locale.ENGLISH).replaceFirstChar { it.titlecase(Locale.ENGLISH) }
    val speechTag: String = tag
    val translationCode: String = tag

    companion object {
        val English = BridgeLanguage("en")
        val Hindi = BridgeLanguage("hi")

        val supported: List<BridgeLanguage> by lazy {
            TranslateLanguage.getAllLanguages()
                .map(::BridgeLanguage)
                .distinctBy(BridgeLanguage::tag)
                .sortedBy(BridgeLanguage::englishName)
        }

        fun fromStored(value: String?): BridgeLanguage? = when (value) {
            "English" -> English
            "Hindi" -> Hindi
            else -> value?.let { stored -> supported.firstOrNull { it.tag == stored } }
        }
    }
}
