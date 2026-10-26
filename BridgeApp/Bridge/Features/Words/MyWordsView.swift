import SwiftUI

struct MyWordsView: View {
    @ObservedObject var words: WordStore
    let talk: TalkModel
    let access: AccessController
    @State private var editing: WordEntry?
    @State private var isAdding = false

    var body: some View {
        Group {
            if words.entries.isEmpty { emptyState } else { list }
        }
        .navigationTitle("My Words")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isAdding = true } label: { Label("Add a word", systemImage: "plus") }
                    .accessTarget("toolbar-add", label: "Add a word", order: 9) { isAdding = true }
            }
        }
        .sheet(isPresented: $isAdding) {
            WordEditor(entry: WordEntry(text: "", kind: .person, language: talk.settings.myLanguage), isNew: true) {
                words.upsert($0)
            }
            .accessHost("word-new", controller: access)
        }
        .sheet(item: $editing) { entry in
            WordEditor(entry: entry, isNew: false) { words.upsert($0) }
                .accessHost("word-edit", controller: access)
        }
    }

    private var list: some View {
        List {
            ForEach(WordKind.allCases) { kind in
                let entries = words.entries(of: kind)
                if !entries.isEmpty {
                    Section(kind.sectionTitle) {
                        ForEach(entries) { entry in
                            WordRow(entry: entry,
                                    onSpeak: { Task { await talk.speaker.speak(entry.text, in: entry.language, rate: talk.settings.speechRate) } },
                                    onOpen: { editing = entry })
                        }
                        .onDelete { offsets in words.delete(Set(offsets.map { entries[$0].id })) }
                    }
                }
            }
            Section {
                Button { isAdding = true } label: { Label("Add a word", systemImage: "plus.circle.fill") }
                    .frame(minHeight: 44)
                    .accessTarget("add", label: "Add a word", order: 9) { isAdding = true }
            } footer: {
                Text("Bridge listens for these words and spells them your way.")
            }
        }
        .accessScrolling()
    }

    private var emptyState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.lg) {
                IconBadge(symbol: "character.book.closed.fill", color: Theme.badge, size: 64)
                Text("No words yet")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Add names Bridge gets wrong, like family members, your doctor, or your street.")
                    .font(.title3)
                    .foregroundStyle(Theme.textSecondary)
                Button { isAdding = true } label: { Label("Add a word", systemImage: "plus") }
                    .buttonStyle(.pill)
                    .accessTarget("add", label: "Add a word") { isAdding = true }
            }
            .padding(Theme.gutter)
            .padding(.top, Theme.Space.lg)
        }
        .background(Theme.background)
    }
}

private struct WordRow: View {
    let entry: WordEntry
    let onSpeak: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: Theme.Space.md) {
            Button(action: onOpen) {
                HStack(spacing: Theme.Space.md) {
                    Image(systemName: entry.kind.symbol)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 28)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.text)
                            .font(.title3.weight(entry.text.containsDevanagari ? .medium : .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text([entry.note, entry.language.englishName].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Edit this word.")
            .accessTarget("open-\(entry.id)", label: entry.text, action: onOpen)

            Button(action: onSpeak) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 44, height: 44)
                    .background(Theme.accent.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Say \(entry.text)")
            .accessTarget("say-\(entry.id)", label: "Hear \(entry.text)", action: onSpeak)
        }
        .frame(minHeight: 52)
    }
}

struct WordEditor: View {
    @State var entry: WordEntry
    let isNew: Bool
    let onSave: (WordEntry) -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    private enum Field { case text, note }

    var body: some View {
        NavigationStack {
            Form {
                Section("How it's spelled") {
                    TextField("Word, name or phrase", text: $entry.text)
                        .font(.title3.weight(.semibold))
                        .focused($focusedField, equals: .text)
                        .frame(minHeight: 44)
                        .accessTarget("text", label: "Word, name or phrase") { focusedField = .text }
                    Picker("Kind", selection: $entry.kind) {
                        ForEach(WordKind.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessPicker("kind", label: "Kind", selection: $entry.kind,
                                  options: WordKind.allCases, title: \.title)
                }
                Section(entry.kind == .person ? "Who it is" : "What it is") {
                    TextField(placeholder, text: $entry.note)
                        .focused($focusedField, equals: .note)
                        .frame(minHeight: 44)
                        .accessTarget("note", label: placeholder) { focusedField = .note }
                }
                Section {
                    Picker("Language", selection: $entry.language) {
                        ForEach(Language.allCases) { Text($0.nativeName).tag($0) }
                    }
                    .accessPicker("language", label: "Language", selection: $entry.language,
                                  options: Language.allCases, title: \.nativeName)
                } header: { Text("How it sounds") } footer: {
                    Text("Bridge listens for this word when you speak \(entry.language.englishName).")
                }
                if !entry.misheard.isEmpty {
                    Section {
                        ForEach(entry.misheard, id: \.self) { Text($0) }
                            .onDelete { entry.misheard.remove(atOffsets: $0) }
                    } header: { Text("Bridge used to hear") } footer: {
                        Text("Bridge changes these to your spelling and tells you when it does.")
                    }
                }
            }
            .accessScrolling()
            .navigationTitle(isNew ? "Add a word" : "Edit word")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(entry.text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .safeAreaInset(edge: .bottom) {
                ButtonRow {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.pillSecondary)
                        .accessTarget("cancel", label: "Cancel", order: 10) { dismiss() }
                    Button("Save") { save() }
                        .buttonStyle(.pill)
                        .disabled(entry.text.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessTarget("save", label: "Save", order: 11) { save() }
                }
                .padding(Theme.gutter)
                .background(.bar)
            }
        }
    }

    private func save() {
        entry.text = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !entry.text.isEmpty else { return }
        onSave(entry)
        dismiss()
    }

    private var placeholder: String {
        switch entry.kind {
        case .person: "My granddaughter"
        case .place: "Where I see my doctor"
        case .phrase: "When I need help"
        case .other: "A word I use often"
        }
    }
}
