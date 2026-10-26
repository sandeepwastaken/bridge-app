package org.congressionalappchallenge.bridge.data

import android.content.Context
import org.json.JSONArray

class BridgeStore(context: Context) {
    private val preferences = context.getSharedPreferences("bridge-local", Context.MODE_PRIVATE)

    var myLanguage: BridgeLanguage
        get() = language("my-language", BridgeLanguage.English)
        set(value) { preferences.edit().putString("my-language", value.tag).apply() }

    var partnerLanguage: BridgeLanguage
        get() = language("partner-language", BridgeLanguage.Hindi)
        set(value) { preferences.edit().putString("partner-language", value.tag).apply() }

    var phraseLanguage: BridgeLanguage
        get() = language("phrase-language", BridgeLanguage.English)
        set(value) { preferences.edit().putString("phrase-language", value.tag).apply() }

    fun ownPhrases(): List<String> = runCatching {
        val values = JSONArray(preferences.getString("own-phrases", "[]"))
        List(values.length()) { values.getString(it) }
    }.getOrDefault(emptyList())

    fun addOwnPhrase(value: String) {
        val cleaned = value.trim().replace("\n", " ")
        if (cleaned.isEmpty()) return
        val updated = (ownPhrases() + cleaned).distinct()
        val json = JSONArray().apply { updated.forEach(::put) }
        preferences.edit().putString("own-phrases", json.toString()).apply()
    }

    fun deleteOwnPhrase(value: String) {
        val json = JSONArray().apply { ownPhrases().filterNot { it == value }.forEach(::put) }
        preferences.edit().putString("own-phrases", json.toString()).apply()
    }

    private fun language(key: String, fallback: BridgeLanguage): BridgeLanguage =
        BridgeLanguage.fromStored(preferences.getString(key, null)) ?: fallback
}
