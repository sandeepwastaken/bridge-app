package org.congressionalappchallenge.bridge

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.test.performScrollTo
import org.junit.Rule
import org.junit.Test

class BridgeUiTest {
    @get:Rule
    val compose = createAndroidComposeRule<MainActivity>()

    @Test
    fun readerPreservesParagraphsAndCanClear() {
        compose.onNodeWithText("Read with me").performScrollTo().performClick()
        compose.onNodeWithText("Original text").performTextInput("Appointment: 10:30.\n\nBring ID.")
        compose.onNodeWithText("Start reading").performClick()
        compose.onNodeWithText("Paragraph 1 of 2").performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("Next").performScrollTo().performClick()
        compose.onNodeWithText("Bring ID.").assertIsDisplayed()
        compose.onNodeWithText("Clear text").performScrollTo().performClick()
        compose.onNodeWithText("Start reading").assertIsDisplayed()
    }

    @Test
    fun homeShowsMainWaysToCommunicate() {
        compose.onNodeWithText("Speak for me").assertIsDisplayed()
        compose.onNodeWithText("Translate").assertIsDisplayed()
        compose.onNodeWithText("Quick phrases").assertIsDisplayed()
    }

    @Test
    fun phrasePickerShowsEnglishAndHindiChoices() {
        compose.onNodeWithText("Quick phrases").performClick()
        compose.onNodeWithText("Say phrases in").performClick()
        compose.onNodeWithText("Search languages").performTextInput("Hindi")
        compose.onNodeWithText("हिन्दी  ·  Hindi").assertIsDisplayed()
    }

    @Test
    fun settingsOfferManyLanguagesAndSearch() {
        compose.onNodeWithText("Settings").performClick()
        compose.onNodeWithText("Translation supports 59 languages. Speech recognition and voices depend on your device and selected language.")
            .assertIsDisplayed()
        compose.onNodeWithText("English · English").performClick()
        compose.onNodeWithText("Search languages").performTextInput("Spanish")
        compose.onNodeWithText("español  ·  Spanish").assertIsDisplayed()
        compose.onNodeWithText("español  ·  Spanish").performClick()
        compose.onNodeWithText("español · Spanish").assertIsDisplayed()
        compose.onNodeWithText("हिन्दी · Hindi").assertIsDisplayed()
    }

    @Test
    fun myWordsCanBeSavedAndRemoved() {
        compose.onNodeWithText("My Words").performClick()
        compose.onNodeWithText("Add a word or phrase").performTextInput("Water, please.")
        compose.onNodeWithText("Save on this device").performClick()
        compose.onNodeWithText("Water, please.").assertIsDisplayed()
        compose.onNodeWithText("Delete").performClick()
        compose.onNodeWithText("Deleted from this device.").assertIsDisplayed()
    }
}
