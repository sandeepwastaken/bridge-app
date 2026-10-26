package org.congressionalappchallenge.bridge

import org.congressionalappchallenge.bridge.data.VoiceCommand
import org.congressionalappchallenge.bridge.data.VoiceCommands
import org.junit.Assert.assertEquals
import org.junit.Test

class VoiceCommandTest {
    @Test fun opensToolsAndPhoneActions() {
        assertEquals(VoiceCommand.Tool("Translate"), VoiceCommands.parse("Please open translate."))
        assertEquals(VoiceCommand.Tool("Together"), VoiceCommands.parse("Talk together"))
        assertEquals(VoiceCommand.Phone("home"), VoiceCommands.parse("Go home"))
        assertEquals(VoiceCommand.Phone("scroll down"), VoiceCommands.parse("Scroll down"))
        assertEquals(VoiceCommand.OpenApp("whatsapp"), VoiceCommands.parse("Open WhatsApp"))
    }

    @Test fun preparesMessagesWithoutDroppingTheirPunctuation() {
        assertEquals(VoiceCommand.Message("Please bring my ID. Appointment: 10:30!"), VoiceCommands.parse("Prepare a message Please bring my ID. Appointment: 10:30!"))
        assertEquals(VoiceCommand.Dial("+15125550100"), VoiceCommands.parse("Call +1 (512) 555-0100"))
        assertEquals(VoiceCommand.Dial(""), VoiceCommands.parse("Call someone"))
    }

    @Test fun unrelatedSpeechDoesNotTriggerActionsBySubstring() {
        assertEquals(VoiceCommand.Unknown, VoiceCommands.parse("I read a book yesterday"))
        assertEquals(VoiceCommand.Unknown, VoiceCommands.parse("Do not go home"))
        assertEquals(VoiceCommand.Unknown, VoiceCommands.parse("The phone call ended"))
    }
}
