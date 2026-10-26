import SwiftUI

struct ImportantInformationView: View {
    var body: some View {
        List {
            Section("Your words, your choice") {
                Text("Bridge helps you prepare, review and speak your words. Check recognized and translated words, especially names, numbers and important decisions, before speaking. Recognition can fail for whispered or impaired speech. A synthesized voice is not voice restoration.")
                Text("Bridge is not an emergency service or a source of medical, legal or financial advice. For urgent help use your local emergency service or a trusted person. For important conversations, use a qualified interpreter or professional when needed.")
            }
            Section("Privacy on this device") {
                Text("Bridge uses on-device speech recognition and translation. It does not record microphone audio to a file or operate a Bridge server. Language models may need downloads. Apple may receive technical framework usage and language-pair metrics; this is different from sending your words to Bridge.")
                Text("New installations do not keep conversation history or automatically speak translated turns. You may enable these choices in Settings. Turning history off stops future saving; use Delete earlier words to remove existing history. My Words is saved only when you choose to save it.")
                Text("Read with me uses text you paste or an article link you choose to open. Fetching a link contacts that website directly. Reading text, key sentences and optional on-device explanations stay in screen memory and are discarded when you leave. Bridge does not see other apps.")
                Text("Ask people before recording or transcribing them and follow the consent rules where you are. Camera head control needs a supported device and permission; Bridge does not save camera images.")
            }
            Section("About Bridge") {
                Text("Built by Rhythmay Girdhar and Sandeep Shenoy, from Rouse High School. No school endorsement is implied.")
                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "102"))")
                    .foregroundStyle(Theme.textSecondary)
                Link("Privacy policy", destination: URL(string: "https://sandeepshenoy.dev/bridge/privacy/")!)
                Link("Contact the maintainers", destination: URL(string: "https://github.com/sandeepwastaken/bridge-app/issues")!)
                Text("These GitHub pages require access to the Bridge repository.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            Section("Platform information") {
                Link("Apple privacy information", destination: URL(string: "https://www.apple.com/legal/privacy/")!)
                Link("Apple Translation documentation", destination: URL(string: "https://developer.apple.com/documentation/translation/translationsession")!)
            }
        }
        .accessScrolling()
        .navigationTitle("Privacy & important information")
    }
}
