import SwiftUI

struct WelcomeView: View {
    @ObservedObject var settings: AppSettings
    let access: AccessController
    let onDone: () -> Void
    @State private var step = 0
    @State private var showImportantInformation = false
    @FocusState private var nameFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Group {
                    switch step {
                    case 0: mission
                    case 1: control
                    case 2: languages
                    default: microphone
                    }
                }
                .padding(Theme.gutter)
                .padding(.top, Theme.Space.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(step)
                .transition(.opacity)
            }
            .accessScrolling()
            footer
        }
        .background(Theme.background.ignoresSafeArea())
        .sheet(isPresented: $showImportantInformation) {
            NavigationStack {
                ImportantInformationView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showImportantInformation = false }
                                .accessTarget("privacy-done", label: "Done", order: 1) { showImportantInformation = false }
                        }
                    }
            }
            .accessHost("important-information", controller: access)
            .dynamicTypeSize(settings.textSize.range)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.21), value: step)
    }

    private var mission: some View {
        VStack(alignment: .leading, spacing: Theme.Space.lg) {
            Text("Welcome to Bridge")
                .font(.system(.largeTitle, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text("A disability, an unfamiliar accent, a language barrier, or difficulty navigating technology should never prevent someone from expressing themselves, understanding another person, or participating independently in everyday life.")
                .font(.title3)
                .foregroundStyle(Theme.textPrimary)
            Button("Privacy & important information") { showImportantInformation = true }
                .frame(minHeight: 48)
                .accessTarget("privacy", label: "Privacy & important information") { showImportantInformation = true }
            Text("Bridge says your words in a clear voice and translates across many languages supported by your device. You can use it with touch, a switch, or head movements.")
                .font(.title3)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var control: some View {
        VStack(alignment: .leading, spacing: Theme.Space.lg) {
            title("How do you like to use your phone?", "You can change this any time in Settings.")
            ForEach(ControlMethod.allCases) { method in
                let available = method != .head || HeadTracker.isSupported
                Button {
                    settings.control = method
                    access.restart()
                } label: {
                    HStack(alignment: .top, spacing: Theme.Space.md) {
                        IconBadge(symbol: method.symbol, color: Theme.badge, size: 44)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(method.title).font(.title3.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                            Text(available ? method.summary : "Needs an iPhone with Face ID.")
                                .font(.body).foregroundStyle(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: settings.control == method ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(settings.control == method ? Theme.accent : Theme.textSecondary.opacity(0.5))
                    }
                    .card(padding: Theme.Space.md, radius: Theme.Radius.lg)
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityIdentifier("method.\(method.rawValue)")
                .accessTarget("method-\(method.rawValue)", label: method.title) {
                    settings.control = method; access.restart()
                }
                .disabled(!available)
                .opacity(available ? 1 : 0.5)
                .accessibilityAddTraits(settings.control == method ? .isSelected : [])
            }
        }
    }

    private var languages: some View {
        VStack(alignment: .leading, spacing: Theme.Space.lg) {
            title("Which languages?", nil)
            languagePicker("I speak", selection: $settings.myLanguage)
            languagePicker("The other person speaks", selection: $settings.partnerLanguage)
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                Text("Their name (optional)").font(.headline).foregroundStyle(Theme.textPrimary)
                TextField("Name", text: $settings.partnerName)
                    .focused($nameFocused)
                    .font(.title3)
                    .padding(Theme.Space.md)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .strokeBorder(Theme.cardBorder, lineWidth: 1))
                    .accessTarget("partner-name", label: "Their name") { nameFocused = true }
            }
        }
    }

    private var microphone: some View {
        VStack(alignment: .leading, spacing: Theme.Space.lg) {
            IconBadge(symbol: "mic.fill", color: Theme.badge, size: 72)
            title("Use the microphone?",
                  "Bridge listens only after you tap Talk. What you say stays on this iPhone.")
        }
    }

    private func title(_ text: String, _ detail: String?) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text(text).font(.largeTitle.weight(.bold)).foregroundStyle(Theme.textPrimary)
            if let detail {
                Text(detail).font(.title3).foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func languagePicker(_ label: String, selection: Binding<Language>) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text(label).font(.headline).foregroundStyle(Theme.textPrimary)
            Menu {
                ForEach(settings.supportedLanguages) { language in
                    Button {
                        selection.wrappedValue = language
                    } label: {
                        Text("\(language.nativeName) · \(language.englishName)")
                    }
                }
            } label: {
                HStack {
                    Text(selection.wrappedValue.nativeName)
                        .font(.title2.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.headline)
                }
                .padding(.horizontal, Theme.Space.md)
                .frame(maxWidth: .infinity, minHeight: Theme.bigControl)
                .foregroundStyle(Theme.textPrimary)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .strokeBorder(Theme.cardBorder, lineWidth: 1))
            }
            .accessPicker("language-\(label)", label: label, selection: selection,
                          options: settings.supportedLanguages) { "\($0.nativeName) · \($0.englishName)" }
        }
    }

    private var footer: some View {
        ButtonRow {
            if step > 0 {
                Button(step == 3 ? "Not now" : "Back") { step == 3 ? onDone() : (step -= 1) }
                    .buttonStyle(.pillSecondary)
                    .accessTarget("back", label: step == 3 ? "Not now" : "Back", order: 10) { step == 3 ? onDone() : (step -= 1) }
            }
            Button(step == 3 ? "Continue to permissions" : (step == 0 ? "Get started" : "Continue")) { next() }
                .buttonStyle(.pill)
                .accessTarget("next", label: step == 3 ? "Continue to permissions" : "Continue", order: 11) { next() }
        }
        .padding(Theme.gutter)
        .background(.bar)
    }

    private func next() {
        if step < 3 {
            step += 1
        } else {
            Task {
                _ = await SpeechRecognizer.requestPermission()
                onDone()
            }
        }
    }
}
