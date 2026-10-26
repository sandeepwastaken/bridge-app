import SwiftUI

struct ReadView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var speaker: Speaker
    @Environment(\.scenePhase) private var scenePhase
    @State private var source = ""
    @State private var parts: [String] = []
    @State private var index = 0
    @State private var voiceUnavailable = false
    @State private var playback: Task<Void, Never>?
    @FocusState private var sourceFocused: Bool
    @State private var keySentences: [String] = []
    @State private var explanation: String?
    @State private var explanationNote: String?
    @State private var isExplaining = false
    @State private var isFetching = false
    @State private var fetchNote: String?
    @State private var startAfterFetch = false
    @State private var fetchTask: Task<Void, Never>?
    @State private var fetchID = UUID()
    @State private var explanationTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.lg) {
                Text("Bring a little text. Take it one paragraph at a time.")
                    .font(.title3).foregroundStyle(Theme.textSecondary)
                Text("Paste or type the original text").font(.headline)
                TextEditor(text: $source)
                    .frame(minHeight: 180)
                    .padding(8)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.cardBorder))
                    .accessibilityLabel("Original text")
                    .accessibilityIdentifier("reader.source")
                    .focused($sourceFocused)
                    .accessTarget("reader-source", label: "Original text") { sourceFocused = true }
                if let link = ArticleFetcher.link(in: source) {
                    Button(isFetching ? "Getting the article…" : "Get the article from this link") { fetch(link) }
                        .buttonStyle(.pill)
                        .disabled(isFetching)
                        .accessibilityIdentifier("reader.fetch")
                        .accessTarget("reader-fetch", label: "Get the article from this link", order: 1) { fetch(link) }
                }
                if let fetchNote {
                    Text(fetchNote).foregroundStyle(Theme.textSecondary)
                }
                Button("Start reading") { beginReading() }
                .buttonStyle(.pill)
                .accessTarget("reader-start", label: "Start reading", order: 1) {
                    beginReading()
                }
                .disabled(source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Key sentences") { findKeySentences() }
                    .buttonStyle(.pillSecondary)
                    .accessTarget("reader-key", label: "Key sentences", order: 1) { findKeySentences() }
                    .disabled(source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if !keySentences.isEmpty { keySentencesCard }

                if !parts.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Space.md) {
                        Text("Paragraph \(index + 1) of \(parts.count)")
                            .font(.headline).foregroundStyle(Theme.textSecondary)
                            .accessibilityIdentifier("reader.progress")
                        Text(parts[index])
                            .font(.title).textSelection(.enabled)
                            .accessibilityIdentifier("reader.paragraph")
                        Button(speaker.isSpeaking ? "Stop reading" : "Read aloud") {
                            if speaker.isSpeaking { stopPlayback() } else { read() }
                        }
                        .buttonStyle(.pill)
                        .accessTarget("reader-speak", label: speaker.isSpeaking ? "Stop reading" : "Read aloud", order: 2) {
                            if speaker.isSpeaking { stopPlayback() } else { read() }
                        }
                        Button(isExplaining ? "Explaining…" : "Explain in simple words") { explainParagraph() }
                            .buttonStyle(.pillSecondary)
                            .disabled(isExplaining)
                            .accessTarget("reader-explain", label: "Explain in simple words", order: 2) { explainParagraph() }
                        if let explanation { explanationCard(explanation) }
                        if let explanationNote {
                            Text(explanationNote).foregroundStyle(Theme.textSecondary)
                        }
                        ButtonRow {
                            Button("Previous") { move(-1) }
                                .buttonStyle(.pillSecondary)
                                .accessTarget("reader-previous", label: "Previous paragraph", order: 3) { move(-1) }
                                .disabled(index == 0)
                            Button("Next") { move(1) }
                                .buttonStyle(.pillSecondary)
                                .accessTarget("reader-next", label: "Next paragraph", order: 4) { move(1) }
                                .disabled(index == parts.count - 1)
                        }
                        .frame(minHeight: Theme.bigControl)
                        if voiceUnavailable {
                            Text("No voice is installed for \(settings.myLanguage.englishName). You can still read the text.")
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .card(padding: Theme.Space.lg, radius: Theme.Radius.lg)
                }

                Button("Clear text", role: .destructive) {
                    stopPlayback(); source = ""; parts = []; index = 0
                }
                .buttonStyle(.pillSecondary)
                .accessTarget("reader-clear", label: "Clear text", order: 5) {
                    stopPlayback(); source = ""; parts = []; index = 0
                }
                Text("The original wording stays unchanged. Key sentences are copied word for word and can leave out important details. Explanations are written on this iPhone by Apple Intelligence and can be wrong, so check the original. None of this is professional advice. Text stays in this screen's memory and is discarded when you leave. Choose its language in Settings before reading aloud.")
                    .font(.footnote).foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: 800, alignment: .leading)
            .padding(Theme.gutter)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { sourceFocused = false }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("reader.keyboardDone")
            }
        }
        .accessScrolling()
        .background(Theme.background)
        .navigationTitle("Read with me")
        .onChange(of: source) { _, _ in
            stopPlayback(); parts = []; index = 0; voiceUnavailable = false; keySentences = []; clearExplanation()
            if startAfterFetch {
                startAfterFetch = false
                beginReading()
            } else {
                fetchTask?.cancel()
                fetchID = UUID()
                isFetching = false
                fetchNote = nil
            }
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { stopPlayback() } }
        .onDisappear { stopPlayback(); fetchTask?.cancel(); explanationTask?.cancel() }
    }

    private func stopPlayback() {
        playback?.cancel()
        playback = nil
        speaker.stop()
    }

    private func beginReading() {
        stopPlayback()
        parts = ReadingText.paragraphs(in: source)
        index = 0
        voiceUnavailable = false
    }

    private func move(_ direction: Int) {
        guard !parts.isEmpty else { return }
        stopPlayback()
        clearExplanation()
        index = min(max(index + direction, 0), parts.count - 1)
    }

    private var keySentencesCard: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            Text("Key sentences, word for word").font(.headline).foregroundStyle(Theme.textSecondary)
            ForEach(Array(keySentences.enumerated()), id: \.offset) { _, sentence in
                Text(sentence).font(.title3).textSelection(.enabled)
            }
            Button("Read these aloud") { speak(keySentences.joined(separator: " ")) }
                .buttonStyle(.pillSecondary)
                .accessTarget("reader-key-speak", label: "Read key sentences aloud", order: 1) {
                    speak(keySentences.joined(separator: " "))
                }
        }
        .card(padding: Theme.Space.lg, radius: Theme.Radius.lg)
        .accessibilityIdentifier("reader.keySentences")
    }

    private func explanationCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Label("Explained by Apple Intelligence. It can be wrong.", systemImage: "sparkles")
                .font(.subheadline).foregroundStyle(Theme.textSecondary)
            Text(text).font(.title3).textSelection(.enabled)
            Button("Read explanation aloud") { speak(text) }
                .buttonStyle(.pillSecondary)
                .accessTarget("reader-explain-speak", label: "Read explanation aloud", order: 2) { speak(text) }
        }
        .padding(Theme.Space.md)
        .background(Theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
    }

    private func fetch(_ url: URL) {
        stopPlayback()
        fetchTask?.cancel()
        let request = UUID()
        fetchID = request
        let original = source
        isFetching = true
        fetchNote = nil
        fetchTask = Task {
            do {
                let text = try await ArticleFetcher.fetch(url)
                guard !Task.isCancelled, fetchID == request, source == original else { return }
                startAfterFetch = true
                fetchNote = "From \(url.host ?? "the link"). Check the original page for anything missing."
                source = text
            } catch {
                guard !Task.isCancelled, fetchID == request else { return }
                fetchNote = "Bridge couldn't read that page. You can copy the article text and paste it here instead."
            }
            isFetching = false
        }
    }

    private func findKeySentences() {
        stopPlayback()
        keySentences = KeySentences.extract(from: source)
    }

    private func clearExplanation() {
        explanationTask?.cancel()
        explanation = nil
        explanationNote = nil
        isExplaining = false
    }

    private func explainParagraph() {
        guard parts.indices.contains(index) else { return }
        clearExplanation()
        if let reason = Explainer.unavailableReason {
            explanationNote = reason
            return
        }
        let paragraph = parts[index]
        let language = settings.myLanguage
        isExplaining = true
        explanationTask = Task {
            do {
                let result = try await Explainer.explain(paragraph, in: language)
                guard !Task.isCancelled, parts.indices.contains(index), parts[index] == paragraph else { return }
                explanation = result
            } catch {
                guard !Task.isCancelled else { return }
                explanationNote = "Apple Intelligence couldn't explain this paragraph right now. Check that Apple Intelligence is on and has finished downloading, then try again. The original text is unchanged."
            }
            isExplaining = false
        }
    }

    private func speak(_ text: String) {
        voiceUnavailable = !Speaker.hasVoice(for: settings.myLanguage)
        guard !voiceUnavailable else { return }
        let language = settings.myLanguage
        let rate = settings.speechRate
        playback?.cancel()
        playback = Task { await speaker.speak(text, in: language, rate: rate) }
    }

    private func read() {
        guard parts.indices.contains(index) else { return }
        voiceUnavailable = !Speaker.hasVoice(for: settings.myLanguage)
        guard !voiceUnavailable else { return }
        let text = parts[index]
        let language = settings.myLanguage
        let rate = settings.speechRate
        playback?.cancel()
        playback = Task {
            guard !Task.isCancelled else { return }
            await speaker.speak(text, in: language, rate: rate)
        }
    }
}
