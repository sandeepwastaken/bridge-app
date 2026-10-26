# Bridge privacy policy

Last updated: 26 October 2026

Bridge is made by Rhythmay Girdhar and Sandeep Shenoy. This policy covers the iOS app, Android app, and local browser preview.

**Contact:** [Bridge maintainers on GitHub](https://github.com/sandeepwastaken/bridge-app/issues). Do not post private messages, recordings, or personal documents in an issue. This policy is also published at [sandeepshenoy.dev/bridge/privacy](https://sandeepshenoy.dev/bridge/privacy/).

## Your words and recordings

Bridge has no account, advertising, or Bridge-operated server. It does not sell your information or upload your messages to a Bridge service.

- **Microphone:** recording starts when you choose a speech feature. Native apps request on-device recognition and offer typing when it is unavailable. Bridge does not save microphone audio to a file.
- **Messages and translations:** typed text, transcripts, corrections, and translation results are processed on your device. Speech and translation support depend on the operating system, language, and downloaded models.
- **Reading:** pasted text, downloaded article text, key sentences, and explanations are held in the current reading screen. They are not added to My Words or conversation history. Bridge does not read text from other applications.
- **Article links:** choosing to fetch a link makes a request directly to that website. The website receives your IP address and ordinary request information under its own privacy practices.
- **Explanations:** the selected paragraph is processed by Apple Intelligence through Foundation Models on supported iPhones, or Gemini Nano through ML Kit and AICore on supported Android devices. Downloads may be required. Bridge does not save the explanation.
- **Voice requests:** a short request is used to choose an action. Messages and calls are prepared for your review; Bridge does not send or dial them automatically.

Ask other people before recording or transcribing them. Follow the consent requirements where you are.

## What stays on your device

Settings, an optional display name, and explicitly saved words or phrases stay in local app storage. On iOS, optional conversation history holds up to 200 messages and session counters track local feature use and timing. Neither is uploaded by Bridge. Android does not keep conversation history.

History is off on a new iOS installation. Turning it off stops future saving; it does not erase existing messages. You can delete history and My Words in Settings. Android phrases can be deleted in My Words. Removing the app removes its local app data, subject to the operating system's backup and restore behavior.

The iOS app protects its saved content files with iOS file protection and excludes those files from iCloud backup. Android disables app backup. Someone with access to an unlocked device may be able to see content displayed in Bridge.

## Permissions and optional controls

- **Microphone and speech recognition:** used for recording a message, microphone captions, or a voice request. You can deny access and type instead.
- **iPhone camera:** used only for enabled head controls on compatible devices. Bridge does not save camera images or send them to a Bridge server. Tracking stops when its active session ends.
- **Personal Voice:** Bridge requests access to a Personal Voice you created in iOS. It does not access the recordings used to create that voice.
- **Sending and calling:** system message, share, and phone screens handle the action after your confirmation. Bridge does not read your contacts, messages, or call history.
- **Android floating assistant:** display-over-other-apps permission allows a movable shortcut circle. You start it explicitly and can stop it from its menu or notification. It does not start at boot, restart automatically, or listen through the overlay service. Notification visibility depends on notification permission.
- **Android phone controls:** a separate accessibility permission enables explicit Home, Back, and scroll actions. The service cannot retrieve window content, ignores accessibility event content, and does not collect screen text or screenshots. Voice capture uses a visible activity and stops when that activity pauses.

Permissions can be changed in the operating system's Settings. Turning off a permission disables the features that need it. Other apps may hide overlays on protected screens.

## Apple and Google services

Apple's Speech, Translation, Foundation Models, and speech synthesis services run the native iOS processing used by Bridge. Language and voice downloads are handled by iOS. Apple's Translation framework may send technical usage and language-pair metrics to Apple; translated text is processed on-device. Apple's services remain subject to [Apple's privacy information](https://www.apple.com/legal/privacy/) and [Translation documentation](https://developer.apple.com/documentation/translation/translationsession).

Android uses Google ML Kit for translation and on-device explanations. Google states that ML Kit processes inputs and outputs on-device. Its SDKs contact Google for model downloads and technical diagnostics. These can include device and app information, identifiers, performance, API configuration, input and output sizes, feature and error events, and translation language settings. Google describes this in its [ML Kit privacy terms](https://developers.google.com/ml-kit/terms) and [Android data disclosure](https://developers.google.com/ml-kit/android-data-disclosure). Explanations use the [GenAI Prompt API](https://developers.google.com/ml-kit/genai/prompt/android).

Bridge does not add a separate analytics or tracking service. Platform and SDK diagnostics are distinct from Bridge's locally stored messages and counters.

## Browser preview

The preview and optional language service run on `127.0.0.1`, on your own computer. Neither binds to a public network interface. The preview forwards explicit requests to the local Python service for Whisper recognition and Argos/CTranslate2 translation. Audio and translation text are not sent to an external inference service by this implementation. Installing dependencies or downloading models contacts their distribution providers.

Preferences, an optional display name, saved phrases, and activity counts remain in browser storage. Unsaved messages, captions, conversation turns, and reader text remain in memory and clear when the page reloads or closes. Clear the site's browser data to remove saved preview information.

Recordings are limited in duration and stop when the recording screen is left or the preview is hidden. The service does not save audio or message content to request logs. Browser speech playback uses voices identified as local.

FaceTime and WhatsApp examples use stock photographs and illustrative captions. They do not connect calls or capture protected call audio. Pictured people are not represented as Bridge users.

## Changes

We update this policy when Bridge's data practices change. The date above identifies this revision. The GitHub distribution described here is separate from App Store or Google Play distribution and their required store disclosures.
