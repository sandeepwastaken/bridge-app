import SwiftUI

struct ShowView: View {
    let message: Message
    @State private var flipped = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.xl) {
                    Text(message.text)
                        .font(.system(size: 56, weight: message.text.containsDevanagari ? .semibold : .bold))
                    if let translation = message.translation {
                        Text(translation)
                            .font(.system(size: 48, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.gutter)
                .padding(.top, Theme.Space.xl)
                .rotationEffect(.degrees(flipped ? 180 : 0))
                .accessibilityElement(children: .combine)
            }

            ButtonRow {
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85)) { flipped.toggle() }
                } label: {
                    Label(flipped ? "Turn back" : "Turn around", systemImage: "arrow.up.arrow.down")
                }
                .buttonStyle(.pillSecondary)
                .accessibilityHint("Flips the words for the person across from you.")
                .accessTarget("flip", label: "Turn around", order: 1) { flipped.toggle() }
                Button("Done") { dismiss() }
                    .buttonStyle(.pill)
                    .accessTarget("done", label: "Done", order: 2) { dismiss() }
            }
            .padding(Theme.gutter)
        }
        .background(Theme.card.ignoresSafeArea())
    }
}
