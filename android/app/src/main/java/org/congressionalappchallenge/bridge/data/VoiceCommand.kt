package org.congressionalappchallenge.bridge.data

sealed interface VoiceCommand {
    data class Tool(val route: String) : VoiceCommand
    data class Phone(val action: String) : VoiceCommand
    data class Dial(val number: String) : VoiceCommand
    data class Message(val body: String) : VoiceCommand
    data class OpenApp(val name: String) : VoiceCommand
    data object Unknown : VoiceCommand
}

object VoiceCommands {
    fun parse(raw: String): VoiceCommand {
        val original = raw.trim().replace(Regex("^please\\s+", RegexOption.IGNORE_CASE), "")
        val text = original.lowercase().trimEnd('.', '!', '?')
        val phone = text.removePrefix("go ")
        if (phone in listOf("home", "back", "scroll up", "scroll down")) return VoiceCommand.Phone(phone)
        for (prefix in listOf("prepare a message ", "send a message ", "text ")) {
            if (text.startsWith(prefix)) return VoiceCommand.Message(original.drop(prefix.length).trim()).takeUnless { it.body.isBlank() } ?: VoiceCommand.Unknown
        }
        if (text.startsWith("call ") || text.startsWith("dial ")) {
            val number = text.substringAfter(' ').filter { it in '0'..'9' || it == '+' }
            return VoiceCommand.Dial(number)
        }
        val destination = text.removePrefix("open ").removePrefix("launch ")
        val route = when (destination) {
            "translate", "translation" -> "Translate"
            "talk together", "conversation" -> "Together"
            "quick phrases", "phrases" -> "Phrases"
            "read", "reader", "read something", "read with me", "understand this", "explain this" -> "Read"
            "my words", "words" -> "Words"
            "speak", "speak for me" -> "Speak"
            "settings", "bridge settings" -> "Settings"
            "assist", "assistant" -> "Assist"
            "floating assistant", "overlay", "phone controls" -> "Overlay"
            "help with a form", "a little guidance", "help with a task" -> "Guidance"
            "bridge home" -> "Home"
            else -> null
        }
        if (route != null) return VoiceCommand.Tool(route)
        return if (text.startsWith("open ") || text.startsWith("launch ")) VoiceCommand.OpenApp(destination).takeUnless { it.name.isBlank() } ?: VoiceCommand.Unknown
        else VoiceCommand.Unknown
    }
}
