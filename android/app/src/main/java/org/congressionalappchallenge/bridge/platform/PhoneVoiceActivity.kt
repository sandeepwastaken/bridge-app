package org.congressionalappchallenge.bridge.platform

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.ActivityNotFoundException
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.net.Uri
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.ScrollView
import org.congressionalappchallenge.bridge.MainActivity
import org.congressionalappchallenge.bridge.data.VoiceCommand
import org.congressionalappchallenge.bridge.data.VoiceCommands

class PhoneVoiceActivity : Activity() {
    private var recognizer: SpeechRecognizer? = null
    private lateinit var feedback: TextView
    private var pendingAction: Runnable? = null
    private val handler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val padding = (20 * resources.displayMetrics.density).toInt()
        val column = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(padding, padding, padding, padding) }
        feedback = TextView(this).apply { text = "Use my voice\n\nSay Open translate, Open WhatsApp, Call someone, Prepare a message, Home, Back, Scroll up, or Scroll down. You review messages and calls before sending or dialing."; textSize = 19f }
        column.addView(feedback)
        fun button(title: String, action: () -> Unit) { column.addView(Button(this).apply { text = title; isAllCaps = false; setOnClickListener { action() } }) }
        button("Start listening", ::beginListening)
        for (action in listOf("Home", "Back", "Scroll up", "Scroll down")) button(action) { useCommand(action) }
        button("Phone control permission") {
            feedback.text = "Enable Bridge phone controls only if you want explicit Home, Back and scroll actions. It does not read screen text."
            startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
        }
        button("Close") { finish() }
        setContentView(ScrollView(this).apply { addView(column) })
        if (intent.getBooleanExtra("bridge.listen", false)) beginListening()
    }

    private fun beginListening() {
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 10)
        else listen()
    }

    private fun listen() {
        if (!SpeechRecognizer.isOnDeviceRecognitionAvailable(this)) { feedback.text = "Local voice recognition is unavailable. Use the buttons instead."; return }
        recognizer?.destroy()
        val current = SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
        recognizer = current
        current.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) { feedback.text = "Microphone on. Say your command." }
            override fun onResults(results: Bundle?) { recognizer?.destroy(); recognizer = null; results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()?.let(::useCommand) }
            override fun onError(error: Int) { feedback.text = "Listening stopped. Try again or choose a button."; recognizer?.destroy(); recognizer = null }
            override fun onBeginningOfSpeech() = Unit
            override fun onRmsChanged(rmsdB: Float) = Unit
            override fun onBufferReceived(buffer: ByteArray?) = Unit
            override fun onEndOfSpeech() = Unit
            override fun onPartialResults(partialResults: Bundle?) = Unit
            override fun onEvent(eventType: Int, params: Bundle?) = Unit
        })
        try { current.startListening(Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-US").putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)) }
        catch (_: Exception) { feedback.text = "The microphone could not start. Use the buttons instead."; current.destroy(); recognizer = null }
    }

    private fun useCommand(raw: String) {
        when (val command = VoiceCommands.parse(raw)) {
        is VoiceCommand.Phone -> {
            val service = BridgePhoneAccessService.active?.get()
            if (service == null) { feedback.text = "Phone control permission is off. Enable it below, or use your phone's own controls."; return }
            recognizer?.destroy(); recognizer = null
            finish()
            pendingAction = Runnable { service.perform(command.action) }
            handler.postDelayed(pendingAction!!, 350)
        }
        is VoiceCommand.Tool -> open(Intent(this, MainActivity::class.java).putExtra("bridge.route", command.route).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP))
        is VoiceCommand.Dial -> open(Intent(Intent.ACTION_DIAL, Uri.parse("tel:${command.number}")))
        is VoiceCommand.Message -> open(Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:")).putExtra("sms_body", command.body))
        is VoiceCommand.OpenApp -> {
            val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
            val matches = packageManager.queryIntentActivities(launcher, 0).filter {
                it.loadLabel(packageManager).toString().equals(command.name, ignoreCase = true)
            }.distinctBy { it.activityInfo.packageName }
            if (matches.size == 1) {
                val app = matches.single().activityInfo
                open(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER).setClassName(app.packageName, app.name))
            } else feedback.text = if (matches.isEmpty()) "No installed app matches ${command.name}. Say the app's full name or open it yourself."
            else "More than one app has that name. Open the one you want from your phone."
        }
        VoiceCommand.Unknown -> feedback.text = "Try Open translate, Call someone, Prepare a message followed by your words, Home, Back, Scroll up, or Scroll down."
        }
    }

    private fun open(intent: Intent) {
        try { startActivity(intent); finish() }
        catch (_: ActivityNotFoundException) { feedback.text = "No app on this phone can do that. Your command has not been sent." }
        catch (_: SecurityException) { feedback.text = "This phone did not allow that action. Use its own controls instead." }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 10 && grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) listen()
        else feedback.text = "Microphone access is off. The buttons still work."
    }
    override fun onPause() { recognizer?.destroy(); recognizer = null; super.onPause() }
}
