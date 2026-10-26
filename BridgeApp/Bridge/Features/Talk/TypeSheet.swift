import SwiftUI

struct TypeSheet: View {
    let language: Language
    let onDone: (String) -> Void

    @State private var text = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text)
                        .font(.title2.weight(.semibold))
                        .frame(minHeight: 180)
                        .focused($focused)
                        .accessibilityLabel("Your words")
                } footer: {
                    Text("Type in \(language.englishName).")
                }
            }
            .navigationTitle("Type your words")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                Button("Use these words") { use() }
                    .buttonStyle(.pill)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .padding(Theme.gutter)
                    .background(.bar)
                    .accessTarget("use", label: "Use these words") { use() }
            }
            .onAppear { focused = true }
        }
    }

    private func use() {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        onDone(text)
        dismiss()
    }
}
