import SwiftUI

struct FixWordsSheet: View {
    let message: Message
    let words: WordStore
    let onDone: (_ text: String, _ remember: [Replacement], _ wordsChanged: Int) -> Void

    @State private var text: String
    @State private var selection: TextSelection?
    @State private var forget: Set<String> = []
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    init(message: Message, words: WordStore, initialWord: String? = nil,
         onDone: @escaping (String, [Replacement], Int) -> Void) {
        self.message = message
        self.words = words
        self.onDone = onDone
        _text = State(initialValue: message.text)
        let target = initialWord ?? message.uncertainWords.first
        if let target, let range = message.text.range(of: target, options: [.caseInsensitive]) {
            _selection = State(initialValue: TextSelection(range: range))
        }
    }

    private var diff: WordDiff { WordDiff(from: message.text, to: text) }

    private var candidates: [Replacement] {
        var seen = Set<String>()
        return diff.substitutions.filter { pair in
            !words.contains(pair.saved) && seen.insert(pair.saved.lowercased()).inserted
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text, selection: $selection)
                        .font(.system(.title2, weight: .bold))
                        .frame(minHeight: 160)
                        .focused($focused)
                        .accessibilityLabel("Your words")
                } footer: {
                    if !message.uncertainWords.isEmpty {
                        Text("Not sure about: " + message.uncertainWords.joined(separator: ", ") + ".")
                    }
                }

                if !candidates.isEmpty {
                    Section {
                        ForEach(candidates, id: \.saved) { pair in
                            Toggle(isOn: binding(for: pair.saved)) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Remember \(pair.saved)")
                                        .font(.system(.body, weight: .semibold))
                                    Text("Bridge heard \(pair.heard)")
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                            .frame(minHeight: 52)
                            .accessToggle("remember-\(pair.saved)", label: "Remember \(pair.saved)",
                                          isOn: binding(for: pair.saved))
                        }
                    } header: {
                        Text("My Words")
                    } footer: {
                        Text("Bridge will listen for saved words and spell them your way.")
                    }
                }
            }
            .formStyle(.grouped)
            .accessScrolling()
            .navigationTitle("Fix words")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { finish() }
                    .fontWeight(.bold)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("Done") { finish() }
                    .buttonStyle(.pill)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .padding(Theme.gutter)
                    .background(.bar)
                    .accessTarget("done", label: "Done") { finish() }
            }
            .onAppear { focused = true }
        }
        .tint(Theme.accent)
    }

    private func finish() {
        let keep = candidates.filter { !forget.contains($0.saved) }
        onDone(text, keep, diff.changedCount)
        dismiss()
    }

    private func binding(for word: String) -> Binding<Bool> {
        Binding(
            get: { !forget.contains(word) },
            set: { keep in
                if keep { forget.remove(word) } else { forget.insert(word) }
            }
        )
    }
}

struct WordDiff {
    let substitutions: [Replacement]
    let changedCount: Int

    init(from original: String, to edited: String) {
        let a = Self.tokens(original)
        let b = Self.tokens(edited)
        let n = a.count, m = b.count
        var table = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        if n > 0, m > 0 {
            for i in stride(from: n - 1, through: 0, by: -1) {
                for j in stride(from: m - 1, through: 0, by: -1) {
                    table[i][j] = Self.same(a[i], b[j]) ? table[i + 1][j + 1] + 1 : max(table[i + 1][j], table[i][j + 1])
                }
            }
        }
        var i = 0, j = 0
        var removed: [String] = [], added: [String] = []
        var pairs: [Replacement] = []
        var changed = 0

        func flush() {
            if removed.count == added.count {
                for (heard, saved) in zip(removed, added) { pairs.append(Replacement(heard: heard, saved: saved)) }
            }
            changed += max(removed.count, added.count)
            removed = []; added = []
        }

        while i < n || j < m {
            if i < n, j < m, Self.same(a[i], b[j]) {
                flush(); i += 1; j += 1
            } else if j < m, i == n || table[i][j + 1] >= table[i + 1][j] {
                added.append(b[j]); j += 1
            } else {
                removed.append(a[i]); i += 1
            }
        }
        flush()
        substitutions = pairs
        changedCount = changed
    }

    private static func tokens(_ text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace)
            .map { String($0).trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
    }

    private static func same(_ x: String, _ y: String) -> Bool {
        x.caseInsensitiveCompare(y) == .orderedSame
    }
}
