import SwiftUI

struct ConversationView: View {
    @ObservedObject var model: TalkModel
    @ObservedObject var recognizer: SpeechRecognizer
    @ObservedObject var settings: AppSettings
    @AppStorage("faceToFace") private var faceToFace = true
    @State private var isTyping = false
    @Environment(\.dynamicTypeSize) private var typeSize

    let access: AccessController

    init(model: TalkModel, access: AccessController) {
        self.model = model
        self.access = access
        self.recognizer = model.recognizer
        self.settings = model.settings
    }

    var body: some View {
        Group {
            if typeSize >= .xxLarge {
                ScrollView { conversation }
                    .accessScrolling()
            } else {
                conversation
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.vertical, Theme.Space.sm)
        .background(Theme.background)
        .navigationTitle("Talk together")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { if model.mode != .conversation { model.mode = .conversation } }
        .sheet(isPresented: $isTyping) {
            TypeSheet(language: settings.myLanguage) { text in
                model.activeSide = .me
                Task { await model.useTyped(text) }
            }
            .accessHost("type", controller: access)
        }
    }

    private var conversation: some View {
        VStack(spacing: Theme.Space.md) {
            half(.partner)
                .rotationEffect(.degrees(faceToFace ? 180 : 0))
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: faceToFace)
                .accessTarget("talk-partner", label: "\(settings.partnerDisplayName): \(talkWord(settings.partnerLanguage))", order: 2) {
                    model.talk(as: .partner)
                }
            middle
            half(.me)
        }
    }

    private var middle: some View {
        HStack(spacing: Theme.Space.sm) {
            Button {
                faceToFace.toggle()
            } label: {
                Label(faceToFace ? "Facing each other" : "Side by side",
                      systemImage: faceToFace ? "arrow.up.and.down.circle.fill" : "rectangle.split.1x2.fill")
                    .font(.subheadline.weight(.semibold))
                    .chip()
            }
            .buttonStyle(PressScaleStyle())
            .foregroundStyle(Theme.accent)
            .accessibilityHint("Turns the top half toward the person across from you.")
            .accessibilityIdentifier("talk.flip")
            .accessTarget("flip", label: faceToFace ? "Side by side" : "Facing each other", order: 5) { faceToFace.toggle() }
        }
    }

    private func half(_ side: Side) -> some View {
        let language = side == .me ? settings.myLanguage : settings.partnerLanguage
        let name = side == .me ? "You" : settings.partnerDisplayName
        let isMyTurnLive = model.activeSide == side && model.isLive
        let otherIsLive = model.activeSide != side && model.isLive

        return VStack(alignment: .leading, spacing: Theme.Space.md) {
            HStack {
                Text("\(name) · \(language.nativeName)")
                    .font(.headline)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                if isMyTurnLive && model.phase == .listening {
                    LevelBars(level: recognizer.level)
                } else if model.phase == .translating && model.activeSide != side {
                    ProgressView()
                }
            }
            if typeSize >= .xxLarge {
                turnText(side, language: language)
            } else {
                ScrollView { turnText(side, language: language) }
                    .scrollBounceBehavior(.basedOnSize)
            }
            let layout = typeSize >= .xxLarge
                ? AnyLayout(VStackLayout(spacing: Theme.Space.md))
                : AnyLayout(HStackLayout(alignment: .top))
            layout {
                if side == .me {
                    CircleControl(title: "Type", symbol: "keyboard", size: .side) { isTyping = true }
                        .disabled(model.isLive || model.phase == .translating)
                        .accessTarget("type-me", label: "Type", order: 3) { isTyping = true }
                }
                if typeSize < .xxLarge { Spacer() }
                CircleControl(
                    title: isMyTurnLive ? stopWord(language) : talkWord(language),
                    symbol: isMyTurnLive ? "stop.fill" : "mic.fill",
                    size: .side,
                    tint: isMyTurnLive ? Theme.recording : Theme.accent,
                    filled: true
                ) { model.talk(as: side) }
                .disabled(otherIsLive || model.phase == .translating)
                .modifier(MyTalkTarget(enabled: side == .me, label: "\(name): \(talkWord(language))") {
                    model.talk(as: side)
                })
                if typeSize < .xxLarge { Spacer() }
                if side == .me && typeSize < .xxLarge {
                    Color.clear.frame(width: 68, height: 1).accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .card(padding: Theme.Space.lg, radius: Theme.Radius.xl)
        .accessibilityElement(children: .contain)
    }

    private func turnText(_ side: Side, language: Language) -> some View {
        Text(words(for: side, language: language))
            .font(Theme.message(for: words(for: side, language: language)))
            .foregroundStyle(hasWords(for: side) ? Theme.textPrimary : Theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func words(for side: Side, language: Language) -> String {
        if case .failed(let failure) = model.phase, model.activeSide == side {
            return failure.message
        }
        if model.phase == .listening, model.activeSide == side {
            return recognizer.partial.isEmpty ? listeningWord(language) : recognizer.partial
        }
        if model.phase == .listening {
            return "…"
        }
        guard let message = model.current else { return hint(language) }
        if message.side == side { return message.text }
        if let translation = message.translation { return translation }
        if model.phase == .translating { return "…" }
        return couldNotTranslate(language) + "\n" + message.text
    }

    private func couldNotTranslate(_ language: Language) -> String {
        language == .hindi ? "अनुवाद नहीं हो सका। उन्होंने कहा:" : "Couldn't translate. They said:"
    }

    private func hasWords(for side: Side) -> Bool {
        model.current != nil || (model.phase == .listening && model.activeSide == side && !recognizer.partial.isEmpty)
    }

    private func hint(_ language: Language) -> String {
        language == .hindi ? "हिन्दी में बोलने के लिए बोलें दबाएँ।" : "Tap Talk and speak in \(language.englishName)."
    }

    private func talkWord(_ language: Language) -> String { language == .hindi ? "बोलें" : "Talk" }
    private func stopWord(_ language: Language) -> String { language == .hindi ? "रुकें" : "Stop" }
    private func listeningWord(_ language: Language) -> String { language == .hindi ? "सुन रहे हैं…" : "Listening…" }
}

private struct MyTalkTarget: ViewModifier {
    let enabled: Bool
    let label: String
    let action: () -> Void

    func body(content: Content) -> some View {
        if enabled {
            content.accessTarget("talk-me", label: label, order: 1, action: action)
        } else {
            content
        }
    }
}
