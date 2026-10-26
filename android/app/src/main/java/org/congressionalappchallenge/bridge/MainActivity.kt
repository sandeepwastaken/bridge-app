package org.congressionalappchallenge.bridge

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.net.Uri
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.core.view.WindowInsetsControllerCompat
import kotlinx.coroutines.launch
import org.congressionalappchallenge.bridge.data.BridgeLanguage
import org.congressionalappchallenge.bridge.data.BridgePhrase
import org.congressionalappchallenge.bridge.data.BridgeStore
import org.congressionalappchallenge.bridge.data.KeySentences
import org.congressionalappchallenge.bridge.data.ArticleText
import org.congressionalappchallenge.bridge.platform.ArticleFetcher
import org.congressionalappchallenge.bridge.data.PhraseBook
import org.congressionalappchallenge.bridge.platform.LocalSpeaker
import org.congressionalappchallenge.bridge.platform.OnDeviceExplainer
import org.congressionalappchallenge.bridge.platform.OnDeviceTranslator

class MainActivity : ComponentActivity() {
    private var recognizer: SpeechRecognizer? = null
    private lateinit var speaker: LocalSpeaker
    var requestedDestination by mutableStateOf<String?>(null)
        private set
    var isListening by mutableStateOf(false)
        private set

    fun consumeDestination() { requestedDestination = null }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        requestedDestination = intent.getStringExtra("bridge.route")
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowInsetsControllerCompat(window, window.decorView).isAppearanceLightStatusBars = true
        speaker = LocalSpeaker(this)
        requestedDestination = intent.getStringExtra("bridge.route")
        setContent { BridgeApp(this, speaker) }
    }

    fun canRecognizeOnDevice(): Boolean = Build.VERSION.SDK_INT >= 31 &&
        SpeechRecognizer.isOnDeviceRecognitionAvailable(this)

    fun listen(language: BridgeLanguage, onText: (String) -> Unit, onError: (String) -> Unit) {
        if (!canRecognizeOnDevice()) {
            onError("On-device speech recognition is not available on this device. You can type instead.")
            return
        }
        stopListening()
        try {
            val current = SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
            recognizer = current
            current.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) { isListening = true }
                override fun onBeginningOfSpeech() = Unit
                override fun onRmsChanged(rmsdB: Float) = Unit
                override fun onBufferReceived(buffer: ByteArray?) = Unit
                override fun onEndOfSpeech() = Unit
                override fun onEvent(eventType: Int, params: Bundle?) = Unit
                override fun onPartialResults(partialResults: Bundle?) = Unit

                override fun onResults(results: Bundle?) {
                    val words = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        ?.firstOrNull()
                    if (words.isNullOrBlank()) onError("No words were recognized. Try again or type instead.")
                    else onText(words)
                    stopListening()
                }

                override fun onError(error: Int) {
                    onError("Speech recognition stopped. Try again or type instead.")
                    stopListening()
                }
            })
            val request = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, language.speechTag)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
            }
            current.startListening(request)
            isListening = true
        } catch (_: UnsupportedOperationException) {
            onError("On-device speech recognition is not available on this device. You can type instead.")
            stopListening()
        } catch (_: SecurityException) {
            onError("Microphone access is needed to listen. You can type instead.")
            stopListening()
        }
    }

    fun stopListening() {
        recognizer?.destroy()
        recognizer = null
        isListening = false
    }

    fun finishListening() { recognizer?.stopListening() }

    override fun onPause() {
        stopListening()
        speaker.stop()
        super.onPause()
    }

    override fun onDestroy() {
        stopListening()
        speaker.close()
        super.onDestroy()
    }
}

private enum class BridgePage(val title: String) {
    Home("Home"), Speak("Speak for me"), Translate("Translate"),
    Together("Talk together"), Phrases("Quick phrases"), Words("My Words"), Read("Read with me"), Settings("Settings"), Assist("Assist"), Guidance("A little guidance"), Overlay("Floating assistant"),
}

@Composable
private fun BridgeApp(activity: MainActivity, speaker: LocalSpeaker) {
    val context = LocalContext.current
    val store = remember { BridgeStore(context) }
    val translator = remember { OnDeviceTranslator() }
    val explainer = remember { OnDeviceExplainer() }
    DisposableEffect(explainer) { onDispose { explainer.close() } }
    val languages = remember { BridgeLanguage.supported }
    val scope = rememberCoroutineScope()
    var page by remember { mutableStateOf(BridgePage.Home) }
    var myLanguage by remember { mutableStateOf(store.myLanguage.takeIf { it in languages } ?: BridgeLanguage.English) }
    var partnerLanguage by remember { mutableStateOf(store.partnerLanguage.takeIf { it in languages } ?: BridgeLanguage.Hindi) }
    var phraseLanguage by remember { mutableStateOf(store.phraseLanguage) }
    var feedback by remember { mutableStateOf("") }
    var pendingSpeechResult by remember { mutableStateOf<((String) -> Unit)?>(null) }
    var pendingSpeechLanguage by remember { mutableStateOf(myLanguage) }
    var showNavigation by remember { mutableStateOf(false) }
    val fontScale = LocalConfiguration.current.fontScale

    val askForMicrophone = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) {
            val result = pendingSpeechResult
            pendingSpeechResult = null
            result?.let {
                activity.listen(pendingSpeechLanguage, it) { feedback = it }
            }
        } else {
            pendingSpeechResult = null
            feedback = "Microphone access is off. You can type instead."
        }
    }

    fun say(text: String, language: BridgeLanguage) {
        feedback = speaker.say(text, language).orEmpty()
    }

    fun listen(language: BridgeLanguage, onText: (String) -> Unit) {
        if (!activity.canRecognizeOnDevice()) {
            feedback = "On-device speech recognition is not available. You can type instead."
        } else if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
            activity.listen(language, onText, { feedback = it })
        } else {
            pendingSpeechLanguage = language
            pendingSpeechResult = onText
            askForMicrophone.launch(Manifest.permission.RECORD_AUDIO)
        }
    }

    LaunchedEffect(activity.requestedDestination) {
        activity.requestedDestination?.let { name -> BridgePage.entries.firstOrNull { it.name == name }?.let { page = it }; activity.consumeDestination() }
    }
    LaunchedEffect(page) {
        pendingSpeechResult = null
        activity.stopListening()
        speaker.stop()
    }

    MaterialTheme(colorScheme = bridgeColorScheme()) {
        Scaffold(
            bottomBar = {
                Row(
                    Modifier.fillMaxWidth().padding(12.dp).background(Color.White.copy(alpha = 0.85f), RoundedCornerShape(32.dp)),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                ) {
                    if (fontScale >= 1.3f) {
                        TextButton(onClick = { showNavigation = true }, modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp)) {
                            Text("Navigate", style = MaterialTheme.typography.titleMedium)
                        }
                    } else {
                        for (target in listOf(BridgePage.Home, BridgePage.Speak, BridgePage.Translate, BridgePage.Assist)) {
                            TextButton(onClick = { page = target }) { Text(target.title, color = if (page == target) Color.Black else Color(0xFF65717E)) }
                        }
                    }
                }
            },
            floatingActionButton = {
                Button(onClick = { page = BridgePage.Assist }, shape = RoundedCornerShape(50)) { Text("Assist") }
            },
            contentWindowInsets = WindowInsets.safeDrawing,
            topBar = {
                if (page != BridgePage.Home) Surface(
                    color = MaterialTheme.colorScheme.background,
                    modifier = Modifier.statusBarsPadding(),
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        if (page != BridgePage.Home) {
                            TextButton(onClick = { page = BridgePage.Home }) { Text("Back") }
                        }
                        Text(
                            text = page.title,
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.padding(vertical = 12.dp),
                        )
                    }
                }
            },
        ) { padding ->
            Column(modifier = Modifier.fillMaxSize().padding(padding)) {
                if (feedback.isNotBlank()) {
                    Text(
                        feedback,
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 8.dp),
                        color = MaterialTheme.colorScheme.error,
                    )
                }
                Crossfade(targetState = page, animationSpec = tween(210), label = "Bridge screen") { currentPage ->
                when (currentPage) {
                    BridgePage.Home -> HomePage(onOpen = { page = it })
                    BridgePage.Assist -> AssistPage(onOpen = { page = it })
                    BridgePage.Guidance -> GuidancePage(onSay = { say(it, BridgeLanguage.English) }, onStop = { speaker.stop() })
                    BridgePage.Overlay -> OverlayPage()
                    BridgePage.Speak -> SpeakPage(
                        language = myLanguage,
                        onListen = { update -> listen(myLanguage, update) },
                        listening = activity.isListening,
                        onFinishListening = { activity.finishListening() },
                        onSay = { say(it, myLanguage) },
                        onSave = { store.addOwnPhrase(it); feedback = "Saved to My Words on this device." },
                        onStop = { speaker.stop() },
                    )
                    BridgePage.Translate -> TranslatePage(
                        from = myLanguage,
                        to = partnerLanguage,
                        translator = translator,
                        onSay = { text, language -> say(text, language) },
                        onFeedback = { feedback = it },
                        onListen = { update -> listen(myLanguage, update) },
                        listening = activity.isListening,
                        onFinishListening = { activity.finishListening() },
                    )
                    BridgePage.Together -> TogetherPage(
                        from = myLanguage,
                        to = partnerLanguage,
                        translator = translator,
                        onSay = { text, language -> say(text, language) },
                        onListen = { language, update -> listen(language, update) },
                        listening = activity.isListening,
                        onFinishListening = { activity.finishListening() },
                    )
                    BridgePage.Phrases -> PhrasesPage(
                        myLanguage = myLanguage,
                        phraseLanguage = phraseLanguage,
                        ownPhrases = store.ownPhrases(),
                        translator = translator,
                        onFeedback = { feedback = it },
                        onPhraseLanguage = { phraseLanguage = it; store.phraseLanguage = it },
                        onSay = { text, language -> say(text, language) },
                    )
                    BridgePage.Words -> WordsPage(
                        words = store.ownPhrases(),
                        onAdd = { store.addOwnPhrase(it); feedback = "Saved on this device." },
                        onDelete = { store.deleteOwnPhrase(it); feedback = "Deleted from this device." },
                    )
                    BridgePage.Read -> ReadPage(
                        language = myLanguage,
                        explainer = explainer,
                        onSay = { say(it, myLanguage) },
                        onStop = { speaker.stop() },
                    )
                    BridgePage.Settings -> SettingsPage(
                        language = myLanguage,
                        partnerLanguage = partnerLanguage,
                        languages = languages,
                        onLanguage = {
                            myLanguage = it
                            store.myLanguage = it
                            if (partnerLanguage == it) {
                                partnerLanguage = languages.first { candidate -> candidate != it }
                                store.partnerLanguage = partnerLanguage
                            }
                        },
                        onPartnerLanguage = {
                            partnerLanguage = it
                            store.partnerLanguage = it
                            if (myLanguage == it) {
                                myLanguage = languages.first { candidate -> candidate != it }
                                store.myLanguage = myLanguage
                            }
                        },
                        canRecognize = activity.canRecognizeOnDevice(),
                    )
                }
                }
            }
        }
        if (showNavigation) {
            val destinations = listOf(BridgePage.Home, BridgePage.Speak, BridgePage.Translate, BridgePage.Assist)
            AlertDialog(
                onDismissRequest = { showNavigation = false },
                title = { Text("Navigate") },
                text = {
                    Column(Modifier.verticalScroll(rememberScrollState())) {
                        destinations.forEach { destination ->
                            TextButton(
                                onClick = { page = destination; showNavigation = false },
                                modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp),
                            ) {
                                Text(destination.title, style = MaterialTheme.typography.titleMedium)
                            }
                        }
                    }
                },
                confirmButton = {
                    TextButton(onClick = { showNavigation = false }) { Text("Close") }
                },
            )
        }
    }
}

@Composable
private fun HomePage(onOpen: (BridgePage) -> Unit) {
    val context = LocalContext.current
    val preferences = remember { context.getSharedPreferences("bridge_profile", 0) }
    val name = preferences.getString("name", "").orEmpty()
    val hour = java.util.Calendar.getInstance().get(java.util.Calendar.HOUR_OF_DAY)
    val greeting = if (hour < 12) "Good morning" else if (hour < 17) "Good afternoon" else "Good evening"
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()),verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Box(Modifier.fillMaxWidth().height(240.dp)) {
            Image(painterResource(R.drawable.bridge_hills), null, Modifier.fillMaxSize(),contentScale = ContentScale.Crop)
            Row(Modifier.fillMaxWidth().padding(22.dp),verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(if (name.isBlank()) greeting else "$greeting, $name", color = Color.White)
                    Text("How can I help?",style = MaterialTheme.typography.headlineSmall,color = Color.White)
                }
                TextButton(onClick = { onOpen(BridgePage.Settings) }) { Text("Settings",color = Color.White) }
            }
        }
        Column(Modifier.padding(horizontal = 20.dp).offset(y = (-40).dp),verticalArrangement = Arrangement.spacedBy(14.dp)) {
            HomeChoice("Speak for me", "Your words, spoken clearly") { onOpen(BridgePage.Speak) }
            BoxWithConstraints {
                val columns = if (maxWidth >= 560.dp) 3 else 1
                if (columns == 3) Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Box(Modifier.weight(1f)) { HomeChoice("Translate","Different languages") { onOpen(BridgePage.Translate) } }
                    Box(Modifier.weight(1f)) { HomeChoice("Talk together","Easier conversations") { onOpen(BridgePage.Together) } }
                    Box(Modifier.weight(1f)) { HomeChoice("Read with me","Text, menus and more") { onOpen(BridgePage.Read) } }
                } else Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    HomeChoice("Translate","Different languages") { onOpen(BridgePage.Translate) }
                    HomeChoice("Talk together","Easier conversations") { onOpen(BridgePage.Together) }
                    HomeChoice("Read with me","Text, menus and more") { onOpen(BridgePage.Read) }
                }
            }
            HomeChoice("Quick phrases", "Please give me a moment. Could you say that again?") { onOpen(BridgePage.Phrases) }
            Card(onClick = { onOpen(BridgePage.Assist) },shape = RoundedCornerShape(26.dp), colors = CardDefaults.cardColors(containerColor = Color(0xFFE9E5FC))) {
                Row(Modifier.fillMaxWidth().padding(12.dp),verticalAlignment = Alignment.CenterVertically) {
                    Image(painterResource(R.drawable.bridge_buddy),null,Modifier.size(120.dp))
                    Text("A little help,\nwhen you need it.", style = MaterialTheme.typography.titleMedium)
                }
            }
            HomeChoice("My Words", "Save phrases that matter to you.") { onOpen(BridgePage.Words) }
        }
    }
}

@Composable
private fun HomeChoice(title: String, description: String, onClick: () -> Unit) {
    Card(
        shape = RoundedCornerShape(26.dp),
        onClick = onClick,
        modifier = Modifier.fillMaxWidth().heightIn(min = 84.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
    ) {
        Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            Text(description, style = MaterialTheme.typography.bodyMedium)
        }
    }
}

@Composable
private fun SpeakPage(
    language: BridgeLanguage,
    onListen: ((String) -> Unit) -> Unit,
    listening: Boolean,
    onFinishListening: () -> Unit,
    onSay: (String) -> Unit,
    onSave: (String) -> Unit,
    onStop: () -> Unit,
) {
    var text by remember { mutableStateOf("") }
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text("Your words stay on this device.", style = MaterialTheme.typography.bodyLarge)
        OutlinedTextField(
            value = text,
            onValueChange = { text = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text("Type what you want to say") },
            minLines = 3,
        )
        Button(onClick = { if (listening) onFinishListening() else onListen { text = it } }, modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp)) {
            Text(if (listening) "Stop recording" else "Talk in ${language.nativeName}")
        }
        Button(
            onClick = { onSay(text) },
            enabled = text.isNotBlank(),
            modifier = Modifier.fillMaxWidth().heightIn(min = 64.dp),
        ) { Text("Say in ${language.nativeName}") }
        OutlinedButton(onClick = onStop, modifier = Modifier.fillMaxWidth()) { Text("Stop") }
        OutlinedButton(onClick = { onSave(text) }, enabled = text.isNotBlank()) { Text("Save to My Words") }
        if (text.isNotBlank()) SendActions(text)
    }
}

@Composable
private fun SendActions(text: String) {
    val context = LocalContext.current
    var note by remember { mutableStateOf("") }
    fun open(intent: Intent) {
        note = try {
            context.startActivity(intent)
            ""
        } catch (_: ActivityNotFoundException) {
            "No app on this phone can do that."
        }
    }
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text("Send or call", style = MaterialTheme.typography.titleMedium)
        AdaptiveActions { buttonModifier ->
            OutlinedButton(
                onClick = { open(Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:")).putExtra("sms_body", text)) },
                modifier = buttonModifier.heightIn(min = 48.dp),
            ) { Text("Text it") }
            OutlinedButton(
                onClick = { open(shareIntent(context, text)) },
                modifier = buttonModifier.heightIn(min = 48.dp),
            ) { Text("Share") }
            OutlinedButton(
                onClick = { open(Intent(Intent.ACTION_DIAL)) },
                modifier = buttonModifier.heightIn(min = 48.dp),
            ) { Text("Call") }
        }
        Text("You choose who it goes to and confirm before anything is sent or dialed.", style = MaterialTheme.typography.bodySmall)
        if (note.isNotBlank()) Text(note, color = MaterialTheme.colorScheme.error)
    }
}

@Composable
private fun AdaptiveActions(content: @Composable (Modifier) -> Unit) {
    if (LocalConfiguration.current.fontScale >= 1.3f) {
        Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(10.dp)) { content(Modifier.fillMaxWidth()) }
    } else {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) { content(Modifier.weight(1f)) }
    }
}

private fun shareIntent(context: Context, text: String): Intent = Intent.createChooser(
    Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, text),
    context.getString(R.string.app_name),
)

@Composable
private fun TranslatePage(
    from: BridgeLanguage,
    to: BridgeLanguage,
    translator: OnDeviceTranslator,
    onSay: (String, BridgeLanguage) -> Unit,
    onFeedback: (String) -> Unit,
    onListen: ((String) -> Unit) -> Unit,
    listening: Boolean,
    onFinishListening: () -> Unit,
) {
    var input by remember { mutableStateOf("") }
    var output by remember { mutableStateOf("") }
    var loading by remember { mutableStateOf(false) }
    var generation by remember { mutableStateOf(0) }
    val scope = rememberCoroutineScope()
    LaunchedEffect(from, to) { generation++; output = "" }
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text("${from.nativeName} to ${to.nativeName}", style = MaterialTheme.typography.titleMedium)
        Text("The first translation downloads a language model over Wi-Fi. Translation runs on this device.")
        OutlinedTextField(
            value = input,
            onValueChange = { generation++; input = it; output = "" },
            modifier = Modifier.fillMaxWidth(),
            label = { Text("Type what you want to say") },
            minLines = 3,
        )
        OutlinedButton(onClick = {
            if (listening) onFinishListening()
            else onListen { generation++; input = it; output = "" }
        }, enabled = !loading, modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp)) {
            Text(if (listening) "Stop recording" else "Talk in ${from.nativeName}")
        }
        Button(
            onClick = {
                loading = true
                output = ""
                onFeedback("")
                val original = input
                val request = ++generation
                scope.launch {
                    runCatching { translator.translate(original, from, to) }
                        .onSuccess { if (request == generation && input == original) output = it }
                        .onFailure { onFeedback("Translation did not finish. Check the Wi-Fi connection and try again.") }
                    loading = false
                }
            },
            enabled = input.isNotBlank() && !loading,
            modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp),
        ) { Text(if (loading) "Getting ${to.englishName} ready…" else "Translate with Google") }
        if (output.isNotBlank()) {
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text("Powered by Google Translate", style = MaterialTheme.typography.labelMedium)
                    Text(output, style = MaterialTheme.typography.headlineSmall)
                    Text("Machine translation can be wrong. Check important messages with a fluent speaker.")
                    Button(onClick = { onSay(output, to) }) { Text("Say in ${to.nativeName}") }
                }
            }
        } else if (!loading && input.isNotBlank()) {
            OutlinedButton(onClick = { onSay(input, from) }) { Text("Say original in ${from.nativeName}") }
        }
    }
}

@Composable
private fun TogetherPage(
    from: BridgeLanguage,
    to: BridgeLanguage,
    translator: OnDeviceTranslator,
    onSay: (String, BridgeLanguage) -> Unit,
    onListen: (BridgeLanguage, (String) -> Unit) -> Unit,
    listening: Boolean,
    onFinishListening: () -> Unit,
) {
    var input by remember { mutableStateOf("") }
    var output by remember { mutableStateOf("") }
    var loading by remember { mutableStateOf(false) }
    var generation by remember { mutableStateOf(0) }
    var error by remember { mutableStateOf("") }
    val scope = rememberCoroutineScope()
    var myTurn by remember { mutableStateOf(true) }
    LaunchedEffect(from, to) { generation++; output = "" }
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text(if (myTurn) "Your turn · ${from.nativeName}" else "Their turn · ${to.nativeName}")
        OutlinedButton(onClick = { generation++; myTurn = !myTurn; input = ""; output = ""; error = "" }, enabled = !listening) { Text("Switch speaker") }
        OutlinedTextField(
            value = input,
            onValueChange = { generation++; input = it; output = "" },
            modifier = Modifier.fillMaxWidth(),
            label = { Text("Type your turn") },
            minLines = 3,
        )
        OutlinedButton(onClick = {
            if (listening) onFinishListening()
            else onListen(if (myTurn) from else to) { generation++; input = it; output = ""; error = "" }
        }, enabled = !loading, modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp)) {
            Text(if (listening) "Stop recording" else "Talk in ${if (myTurn) from.nativeName else to.nativeName}")
        }
        Button(
            onClick = {
                loading = true
                output = ""
                error = ""
                val original = input
                val request = ++generation
                val source = if (myTurn) from else to
                val target = if (myTurn) to else from
                scope.launch {
                    runCatching { translator.translate(original, source, target) }
                        .onSuccess { if (request == generation && input == original) output = it }
                        .onFailure { error = "Translation did not finish. Your original words are still here." }
                    loading = false
                }
            },
            enabled = input.isNotBlank() && !loading,
            modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp),
        ) { Text(if (loading) "Translating…" else "Translate this turn") }
        if (error.isNotBlank()) {
            Text(error, color = MaterialTheme.colorScheme.error)
            OutlinedButton(onClick = { onSay(input, if (myTurn) from else to) }) { Text("Say original in ${if (myTurn) from.nativeName else to.nativeName}") }
        }
        if (output.isNotBlank()) {
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(output, style = MaterialTheme.typography.headlineSmall)
                    Button(onClick = { onSay(output, if (myTurn) to else from) }) { Text("Say in ${if (myTurn) to.nativeName else from.nativeName}") }
                }
            }
        }
    }
}

@Composable
private fun PhrasesPage(
    myLanguage: BridgeLanguage,
    phraseLanguage: BridgeLanguage,
    ownPhrases: List<String>,
    translator: OnDeviceTranslator,
    onFeedback: (String) -> Unit,
    onPhraseLanguage: (BridgeLanguage) -> Unit,
    onSay: (String, BridgeLanguage) -> Unit,
) {
    val configuration = LocalConfiguration.current
    val translations = remember { mutableStateMapOf<String, String>() }
    var loading by remember { mutableStateOf(false) }
    val columns = when {
        configuration.fontScale >= 1.3f -> 1
        configuration.screenWidthDp >= 600 -> 2
        else -> 1
    }
    LaunchedEffect(myLanguage, phraseLanguage, ownPhrases) {
        translations.clear()
        loading = phraseLanguage != BridgeLanguage.English && phraseLanguage != BridgeLanguage.Hindi ||
            (ownPhrases.isNotEmpty() && myLanguage != phraseLanguage)
        onFeedback("")
        try {
            if (phraseLanguage == BridgeLanguage.English || phraseLanguage == BridgeLanguage.Hindi) {
                PhraseBook.all.forEach { translations[it.id] = it.text(phraseLanguage) }
            } else {
                val results = translator.translateMany(
                    PhraseBook.all.map(BridgePhrase::english),
                    BridgeLanguage.English,
                    phraseLanguage,
                )
                PhraseBook.all.zip(results).forEach { (phrase, translated) -> translations[phrase.id] = translated }
            }
            if (ownPhrases.isNotEmpty()) {
                if (myLanguage == phraseLanguage) {
                    ownPhrases.forEach { translations["own:$it"] = it }
                } else {
                    val results = translator.translateMany(ownPhrases, myLanguage, phraseLanguage)
                    ownPhrases.zip(results).forEach { (phrase, translated) -> translations["own:$phrase"] = translated }
                }
            }
        } catch (_: Exception) {
            onFeedback("Couldn't prepare phrases in ${phraseLanguage.englishName}. Check Wi-Fi or choose another language.")
        }
        loading = false
    }
    Column(Modifier.fillMaxSize().padding(horizontal = 20.dp)) {
        LanguagePicker("Say phrases in", phraseLanguage, BridgeLanguage.supported, onPhraseLanguage)
        Text(
            if (loading) "Preparing phrases on this device…" else "The first use of a new language downloads its model over Wi-Fi.",
            style = MaterialTheme.typography.bodySmall,
            modifier = Modifier.padding(top = 4.dp, bottom = 10.dp),
        )
        BoxWithConstraints(Modifier.fillMaxSize()) {
            LazyVerticalGrid(
                columns = GridCells.Fixed(columns),
                contentPadding = PaddingValues(bottom = 24.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                if (ownPhrases.isNotEmpty()) {
                    item(span = { androidx.compose.foundation.lazy.grid.GridItemSpan(maxLineSpan) }) {
                        Text("My phrases", style = MaterialTheme.typography.titleLarge)
                    }
                    items(ownPhrases, key = { "own-$it" }) { phrase ->
                        val translated = translations["own:$phrase"]
                        PhraseTile(
                            mainText = translated ?: "Preparing phrase…",
                            otherText = if (myLanguage == phraseLanguage) null else phrase,
                            spokenLanguage = phraseLanguage,
                            enabled = translated != null,
                            onSay = { onSay(translated ?: phrase, phraseLanguage) },
                        )
                    }
                }
                PhraseBook.groups.forEach { group ->
                    item(span = { androidx.compose.foundation.lazy.grid.GridItemSpan(maxLineSpan) }) {
                        Text(group.title, style = MaterialTheme.typography.titleLarge)
                    }
                    items(group.phrases, key = BridgePhrase::id) { phrase ->
                        val translated = translations[phrase.id]
                        PhraseTile(
                            mainText = translated ?: if (loading) "Preparing phrase…" else phrase.english,
                            otherText = if (phraseLanguage == BridgeLanguage.English) phrase.hindi else phrase.english,
                            spokenLanguage = phraseLanguage,
                            enabled = translated != null,
                            onSay = { onSay(translated ?: phrase.english, phraseLanguage) },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun PhraseTile(
    mainText: String,
    otherText: String?,
    spokenLanguage: BridgeLanguage,
    enabled: Boolean = true,
    onSay: () -> Unit,
) {
    Card(
        onClick = onSay,
        enabled = enabled,
        modifier = Modifier.fillMaxWidth().heightIn(min = 148.dp)
            .semantics { contentDescription = "Say $mainText in ${spokenLanguage.englishName}" },
    ) {
        Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("Bridge will say this", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.primary)
            Text(mainText, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
            if (otherText != null) Text(otherText, style = MaterialTheme.typography.bodyLarge)
        }
    }
}

@Composable
private fun LanguagePicker(
    label: String,
    selected: BridgeLanguage,
    languages: List<BridgeLanguage>,
    onSelected: (BridgeLanguage) -> Unit,
) {
    var showing by remember { mutableStateOf(false) }
    var query by remember { mutableStateOf("") }
    OutlinedButton(onClick = { query = ""; showing = true }, modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(label)
            Text("${selected.nativeName} · ${selected.englishName}", fontWeight = FontWeight.SemiBold)
        }
    }
    if (showing) {
        val filtered = languages.filter {
            it.englishName.contains(query, ignoreCase = true) || it.nativeName.contains(query, ignoreCase = true)
        }
        AlertDialog(
            onDismissRequest = { showing = false },
            title = { Text(label) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(
                        value = query,
                        onValueChange = { query = it },
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text("Search languages") },
                        singleLine = true,
                    )
                    LazyColumn(Modifier.heightIn(max = 360.dp)) {
                        items(filtered, key = BridgeLanguage::tag) { option ->
                            TextButton(
                                onClick = { onSelected(option); showing = false },
                                modifier = Modifier.fillMaxWidth(),
                            ) {
                                Text("${option.nativeName}  ·  ${option.englishName}", modifier = Modifier.fillMaxWidth())
                            }
                        }
                    }
                }
            },
            confirmButton = { TextButton(onClick = { showing = false }) { Text("Close") } },
        )
    }
}

@Composable
private fun WordsPage(words: List<String>, onAdd: (String) -> Unit, onDelete: (String) -> Unit) {
    var entry by remember { mutableStateOf("") }
    Column(Modifier.fillMaxSize().padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        OutlinedTextField(
            value = entry,
            onValueChange = { entry = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text("Add a word or phrase") },
        )
        Button(onClick = { onAdd(entry); entry = "" }, enabled = entry.isNotBlank()) { Text("Save on this device") }
        LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            items(words, key = { it }) { word ->
                Card(Modifier.fillMaxWidth()) {
                    Row(Modifier.padding(14.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(word, modifier = Modifier.weight(1f))
                        TextButton(onClick = { onDelete(word) }) { Text("Delete") }
                    }
                }
            }
        }
    }
}

@Composable
private fun SettingsPage(
    language: BridgeLanguage,
    partnerLanguage: BridgeLanguage,
    languages: List<BridgeLanguage>,
    onLanguage: (BridgeLanguage) -> Unit,
    onPartnerLanguage: (BridgeLanguage) -> Unit,
    canRecognize: Boolean,
) {
    val context = LocalContext.current
    val version = remember { context.packageManager.getPackageInfo(context.packageName, 0) }
    val profile = remember { context.getSharedPreferences("bridge_profile", 0) }
    var name by remember { mutableStateOf(profile.getString("name", "").orEmpty()) }
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        OutlinedTextField(value = name, onValueChange = { name = it.take(40); profile.edit().putString("name", name).apply() }, label = { Text("What should I call you?") }, modifier = Modifier.fillMaxWidth())
        LanguagePicker("I speak", language, languages, onLanguage)
        LanguagePicker("They speak", partnerLanguage, languages, onPartnerLanguage)
        Text("Translation supports ${languages.size} languages. Speech recognition and voices depend on your device and selected language.")
        Text("On-device speech recognition: ${if (canRecognize) "available for supported languages" else "not available on this device"}")
        Text("Privacy & important information", style = MaterialTheme.typography.titleLarge)
        Text("Bridge helps you prepare, review and speak your words. Check recognized and translated words before speaking, especially names and numbers. Whispered or impaired speech may not be recognized. It is not medical, legal or financial advice, or an emergency service.")
        Text("Ask other people before recording or transcribing them. Read with me uses pasted text or an article link you choose to open. Fetching a link contacts that website directly. Text, key sentences and optional on-device explanations stay in screen memory; Bridge does not read other apps.")
        Text("Bridge asks for microphone access when you choose a speech feature. It uses the on-device recognizer when supported. Saved phrases stay on this device. Translation models download over Wi-Fi and translate locally after download. Bridge has no account, ads, or separate analytics service.")
        Text("Android translation is powered by Google Translate. Google ML Kit processes translation text on this device. Google says ML Kit may send device and app details, performance metrics, and translation language settings to Google over HTTPS for diagnostics and service analytics. See Google's ML Kit privacy details and Google Translate attribution requirements in the release documentation.")
        Text("THIS SERVICE MAY CONTAIN TRANSLATIONS POWERED BY GOOGLE. GOOGLE DISCLAIMS ALL WARRANTIES RELATED TO THE TRANSLATIONS, EXPRESS OR IMPLIED, INCLUDING ANY WARRANTIES OF ACCURACY, RELIABILITY, AND ANY IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.", style = MaterialTheme.typography.bodySmall)
        Text("Saved phrases are stored in app-only storage. You can delete them in My Words. Removing Bridge deletes its app data.")
        Text("The optional floating assistant needs display permission. Home, Back and scroll actions need separate accessibility access. Bridge phone controls do not retrieve screen content or take screenshots. The overlay does not listen in the background; stop it from its menu or notification.")
        Text("Built by Rhythmay Girdhar and Sandeep Shenoy, from Rouse High School. No school endorsement is implied.")
        Text("Version ${version.versionName} (${version.longVersionCode})", color = MaterialTheme.colorScheme.onSurfaceVariant)
        TextButton(onClick = { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://sandeepshenoy.dev/bridge/privacy/"))) }) { Text("Privacy policy") }
        TextButton(onClick = { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://github.com/sandeepwastaken/bridge-app/issues"))) }) { Text("Contact the maintainers") }
        Text("These GitHub pages require access to the Bridge repository.", style = MaterialTheme.typography.bodySmall)
    }
}

@Composable
private fun bridgeColorScheme() = androidx.compose.material3.lightColorScheme(
    primary = androidx.compose.ui.graphics.Color(0xFF101215),
    onPrimary = androidx.compose.ui.graphics.Color.White,
    primaryContainer = androidx.compose.ui.graphics.Color(0xFFEDEBFF),
    onPrimaryContainer = androidx.compose.ui.graphics.Color(0xFF101D45),
    background = androidx.compose.ui.graphics.Color(0xFFEEF4FA),
    surface = androidx.compose.ui.graphics.Color.White,
    onSurface = androidx.compose.ui.graphics.Color(0xFF101215),
)


@Composable
private fun ReadPage(language: BridgeLanguage, explainer: OnDeviceExplainer, onSay: (String) -> Unit, onStop: () -> Unit) {
    val scope = rememberCoroutineScope()
    var source by remember { mutableStateOf("") }
    var paragraphs by remember { mutableStateOf(emptyList<String>()) }
    var index by remember { mutableStateOf(0) }
    var keySentences by remember { mutableStateOf(emptyList<String>()) }
    var explanation by remember { mutableStateOf("") }
    var explainNote by remember { mutableStateOf("") }
    var explaining by remember { mutableStateOf(false) }
    var needsDownload by remember { mutableStateOf(false) }
    var fetching by remember { mutableStateOf(false) }
    var fetchNote by remember { mutableStateOf("") }

    fun clearExplanation() { explanation = ""; explainNote = ""; explaining = false; needsDownload = false }

    fun explain(paragraph: String) {
        clearExplanation()
        explaining = true
        scope.launch {
            when (explainer.status()) {
                OnDeviceExplainer.Status.Ready -> try {
                    val result = explainer.explain(paragraph, language)
                    if (paragraphs.getOrNull(index) == paragraph) {
                        if (result.isBlank()) explainNote = "Bridge could not explain this paragraph. The original text is unchanged."
                        else explanation = result
                    }
                } catch (_: Exception) {
                    explainNote = "Bridge could not explain this paragraph. The original text is unchanged."
                }
                OnDeviceExplainer.Status.NeedsDownload -> {
                    needsDownload = true
                    explainNote = "Explanations use Google's on-device model. It needs a one-time download."
                }
                OnDeviceExplainer.Status.Downloading -> explainNote = "The on-device model is still downloading. Try again soon."
                OnDeviceExplainer.Status.Unavailable -> explainNote = "Explanations need a phone that supports Gemini Nano."
            }
            explaining = false
        }
    }

    fun download() {
        needsDownload = false
        explainNote = "Downloading the on-device model. You can keep reading."
        scope.launch {
            explainNote = try {
                if (explainer.download()) "The model is ready. Choose Explain in simple words again."
                else "The model is still getting ready. Try again soon."
            } catch (_: Exception) {
                "The download did not finish. Check your connection and try again."
            }
        }
    }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text("Bring a little text. Take it one paragraph at a time.", style = MaterialTheme.typography.titleLarge)
        OutlinedTextField(
            value = source,
            onValueChange = { source = it; paragraphs = emptyList(); index = 0; keySentences = emptyList(); fetchNote = ""; clearExplanation(); onStop() },
            label = { Text("Original text or article link") },
            modifier = Modifier.fillMaxWidth().heightIn(min = 180.dp),
        )
        ArticleText.link(source)?.let { link ->
            Button(onClick = {
                onStop()
                fetching = true
                fetchNote = ""
                val original = source
                scope.launch {
                    try {
                        val article = ArticleFetcher.fetch(link)
                        if (source == original) {
                            source = article
                            paragraphs = org.congressionalappchallenge.bridge.data.ReadingText.paragraphs(article)
                            index = 0
                            keySentences = emptyList()
                            clearExplanation()
                            fetchNote = "From ${link.host}. Check the original page for anything missing."
                        }
                    } catch (_: Exception) {
                        if (source == original) fetchNote = "Bridge couldn't read that page. Copy the article text and paste it here instead."
                    } finally {
                        fetching = false
                    }
                }
            }, enabled = !fetching, modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp)) {
                Text(if (fetching) "Getting the article…" else "Get the article from this link")
            }
        }
        if (fetchNote.isNotBlank()) Text(fetchNote)
        Button(
            onClick = { onStop(); paragraphs = org.congressionalappchallenge.bridge.data.ReadingText.paragraphs(source); index = 0; clearExplanation() },
            enabled = source.isNotBlank(),
            modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp),
        ) { Text("Start reading") }
        OutlinedButton(
            onClick = { onStop(); keySentences = KeySentences.extract(source, locale = language.locale) },
            enabled = source.isNotBlank(),
            modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp),
        ) { Text("Key sentences") }
        if (keySentences.isNotEmpty()) {
            Card(shape = RoundedCornerShape(26.dp)) {
                Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text("Key sentences, word for word", style = MaterialTheme.typography.titleMedium)
                    keySentences.forEach { Text(it, style = MaterialTheme.typography.titleLarge) }
                    OutlinedButton(onClick = { onSay(keySentences.joinToString(" ")) }, modifier = Modifier.fillMaxWidth()) { Text("Read these aloud") }
                }
            }
        }
        if (paragraphs.isNotEmpty()) {
            Text("Paragraph ${index + 1} of ${paragraphs.size}", style = MaterialTheme.typography.titleMedium)
            Text(paragraphs[index], style = MaterialTheme.typography.headlineSmall)
            Button(onClick = { onSay(paragraphs[index]) }, modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp)) {
                Text("Read aloud")
            }
            OutlinedButton(onClick = onStop, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)) { Text("Stop reading") }
            OutlinedButton(
                onClick = { explain(paragraphs[index]) },
                enabled = !explaining,
                modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp),
            ) { Text(if (explaining) "Explaining…" else "Explain in simple words") }
            if (explanation.isNotBlank()) {
                Card(shape = RoundedCornerShape(20.dp)) {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text("Explained by Gemini Nano on this phone. It can be wrong.", style = MaterialTheme.typography.bodySmall)
                        Text(explanation, style = MaterialTheme.typography.titleLarge)
                        OutlinedButton(onClick = { onSay(explanation) }, modifier = Modifier.fillMaxWidth()) { Text("Read explanation aloud") }
                    }
                }
            }
            if (explainNote.isNotBlank()) Text(explainNote)
            if (needsDownload) OutlinedButton(onClick = { download() }, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)) { Text("Download the model") }
            AdaptiveActions { buttonModifier ->
                OutlinedButton(onClick = { onStop(); clearExplanation(); index-- }, enabled = index > 0, modifier = buttonModifier.heightIn(min = 48.dp)) { Text("Previous") }
                OutlinedButton(onClick = { onStop(); clearExplanation(); index++ }, enabled = index < paragraphs.lastIndex, modifier = buttonModifier.heightIn(min = 48.dp)) { Text("Next") }
            }
        }
        TextButton(onClick = { onStop(); source = ""; paragraphs = emptyList(); index = 0; keySentences = emptyList(); fetchNote = ""; clearExplanation() }, modifier = Modifier.heightIn(min = 48.dp)) { Text("Clear text") }
        Text("Original wording stays unchanged. Key sentences are copied word for word and can leave out important details. Explanations are written on this phone and can be wrong, so check the original. None of this is professional advice. Text stays in screen memory until you leave. Choose its language in Settings before reading aloud.")
    }
}

@Composable
private fun AssistPage(onOpen: (BridgePage) -> Unit) {
    val context = LocalContext.current
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Image(painterResource(R.drawable.bridge_buddy), null, Modifier.fillMaxWidth().height(200.dp))
        Text("Hello. What do you need?",style = MaterialTheme.typography.headlineSmall)
        Button(onClick = { context.startActivity(Intent(context, org.congressionalappchallenge.bridge.platform.PhoneVoiceActivity::class.java).putExtra("bridge.listen", true)) }, modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp)) { Text("Use my voice") }
        HomeChoice("Read something", "One small part at a time") { onOpen(BridgePage.Read) }
        HomeChoice("Help with a task", "Take the next step at your pace") { onOpen(BridgePage.Guidance) }
        HomeChoice("Speak for me", "Your words, spoken clearly") { onOpen(BridgePage.Speak) }
        HomeChoice("Translate", "A message in another language") { onOpen(BridgePage.Translate) }
        HomeChoice("Quick phrases", "Common things you might say") { onOpen(BridgePage.Phrases) }
        HomeChoice("My Words", "Your saved phrases") { onOpen(BridgePage.Words) }
        HomeChoice("Floating assistant", "Voice and phone controls") { onOpen(BridgePage.Overlay) }
    }
}

@Composable
private fun GuidancePage(onSay: (String) -> Unit, onStop: () -> Unit) {
    var step by remember { mutableStateOf(0) }
    val steps = listOf(
        "Read the instructions" to "Check who the form is for and what information it asks you to provide. Keep the original page open.",
        "Take one field at a time" to "Use your own details. If a question is unclear, ask the organization before guessing.",
        "Check before submitting" to "Review names, dates and contact details. You choose whether to submit.",
    )
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text("Fill in a form · Step ${step + 1} of ${steps.size}")
        Card(shape = RoundedCornerShape(26.dp)) {
            Column(Modifier.padding(20.dp),verticalArrangement = Arrangement.spacedBy(18.dp)) {
                Text(steps[step].first,style = MaterialTheme.typography.headlineSmall)
                Text(steps[step].second)
                Button(onClick = { onStop(); step = (step + 1) % steps.size },modifier = Modifier.fillMaxWidth()) { Text(if (step == 2) "Start again" else "Next step") }
                OutlinedButton(onClick = { onSay(steps[step].first + ". " + steps[step].second) },modifier = Modifier.fillMaxWidth()) { Text("Read aloud") }
            }
        }
        OutlinedButton(onClick = { onStop(); step = (step - 1).coerceAtLeast(0) },enabled = step > 0) { Text("Previous step") }
        Text("You stay in control. Bridge does not submit a form or send a message for you.")
    }
}

@Composable
private fun OverlayPage() {
    val context = LocalContext.current
    var feedback by remember { mutableStateOf("") }
    val askNotifications = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text("A little help beside your task",style = MaterialTheme.typography.headlineSmall)
        Text("The assistant can show a small circle over other apps after you allow it. It does not read those screens or listen in the background. Some protected screens may hide overlays.")
        Button(onClick = {
            if (!Settings.canDrawOverlays(context)) {
                context.startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${context.packageName}")))
                feedback = "Allow display over other apps if you want the circle. Return here and choose Start assistant."
            } else {
                try {
                    ContextCompat.startForegroundService(context, Intent(context, org.congressionalappchallenge.bridge.platform.BridgeOverlayService::class.java))
                    feedback = "The assistant is on. Use the circle or its notification to stop it."
                } catch (_: Exception) { feedback = "The assistant could not start. You can still use all tools inside Bridge." }
            }
        },modifier = Modifier.fillMaxWidth()) { Text("Start assistant") }
        OutlinedButton(onClick = { context.stopService(Intent(context, org.congressionalappchallenge.bridge.platform.BridgeOverlayService::class.java)); feedback = "Assistant stopped." },modifier = Modifier.fillMaxWidth()) { Text("Stop assistant") }
        Button(onClick = { context.startActivity(Intent(context, org.congressionalappchallenge.bridge.platform.PhoneVoiceActivity::class.java)) },modifier = Modifier.fillMaxWidth()) { Text("Voice and phone controls") }
        Text("Phone Home, Back and scroll controls need a separate accessibility permission. Bridge performs only the explicit command you choose. It does not retrieve window text or take screenshots.")
        if (Build.VERSION.SDK_INT >= 33) OutlinedButton(onClick = { askNotifications.launch(Manifest.permission.POST_NOTIFICATIONS) }) { Text("Allow the assistant notification") }
        Text(feedback)
    }
}
