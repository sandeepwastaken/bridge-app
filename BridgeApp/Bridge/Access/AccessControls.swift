import SwiftUI

struct AccessChoice: Identifiable {
    let id: String
    let title: String
    var isSelected = false
    var role: ButtonRole?
    let action: () -> Void
}

extension View {
    func accessChoices(_ id: String, label: String, order: Int = 0,
                       choices: @escaping () -> [AccessChoice]) -> some View {
        modifier(AccessChoicesModifier(id: id, label: label, order: order, choices: choices))
    }

    func accessPicker<Value: Hashable>(_ id: String, label: String, order: Int = 0, selection: Binding<Value>,
                                       options: [Value], title: @escaping (Value) -> String) -> some View {
        accessChoices(id, label: label, order: order) {
            options.map { option in
                AccessChoice(id: title(option), title: title(option), isSelected: option == selection.wrappedValue) {
                    selection.wrappedValue = option
                }
            }
        }
    }

    func accessToggle(_ id: String, label: String, order: Int = 0, isOn: Binding<Bool>) -> some View {
        accessTarget(id, label: label, order: order) { isOn.wrappedValue.toggle() }
    }
}

private struct AccessChoicesModifier: ViewModifier {
    let id: String
    let label: String
    let order: Int
    let choices: () -> [AccessChoice]
    @Environment(\.accessController) private var controller
    @State private var isPresented = false

    func body(content: Content) -> some View {
        content
            .accessTarget(id, label: label, order: order) { isPresented = true }
            .sheet(isPresented: $isPresented) {
                if let controller {
                    AccessChoiceList(title: label, choices: choices()) { isPresented = false }
                        .accessHost("choices-\(id)", controller: controller)
                }
            }
    }
}

private struct AccessChoiceList: View {
    let title: String
    let choices: [AccessChoice]
    let close: () -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(choices) { choice in
                    Button(role: choice.role) { choose(choice) } label: {
                        HStack {
                            Text(choice.title)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(choice.role == .destructive ? Color.red : Theme.textPrimary)
                            Spacer()
                            if choice.isSelected {
                                Image(systemName: "checkmark").font(.headline).foregroundStyle(Theme.accent)
                            }
                        }
                        .frame(minHeight: 52)
                        .contentShape(Rectangle())
                    }
                    .accessibilityAddTraits(choice.isSelected ? .isSelected : [])
                    .accessTarget("choice-\(choice.id)", label: choice.title) { choose(choice) }
                }
            }
            .accessScrolling()
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: close) }
            }
            .safeAreaInset(edge: .bottom) {
                Button("Cancel", action: close)
                    .buttonStyle(.pillSecondary)
                    .padding(Theme.gutter)
                    .background(.bar)
                    .accessTarget("cancel", label: "Cancel", order: 10, action: close)
            }
        }
        .tint(Theme.accent)
    }

    private func choose(_ choice: AccessChoice) {
        choice.action()
        close()
    }
}

struct AccessSlider<Value: BinaryFloatingPoint>: View where Value.Stride: BinaryFloatingPoint {
    let id: String
    let label: String
    @Binding var value: Value
    let range: ClosedRange<Value>
    let step: Value
    var continuous = false
    var lowSymbol = "minus"
    var highSymbol = "plus"
    var lowName = "Less"
    var highName = "More"

    var body: some View {
        HStack(spacing: Theme.Space.md) {
            stepButton(lowSymbol, lowName, -step)
            if continuous {
                Slider(value: $value, in: range) { Text(label) }
            } else {
                Slider(value: $value, in: range, step: Value.Stride(step)) { Text(label) }
            }
            stepButton(highSymbol, highName, step)
        }
    }

    private func stepButton(_ symbol: String, _ name: String, _ delta: Value) -> some View {
        Button { adjust(delta) } label: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 44, height: 44)
                .background(Theme.accent.opacity(0.12), in: Circle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("\(label): \(name)")
        .accessTarget("\(id)-\(name)", label: "\(label): \(name)") { adjust(delta) }
    }

    private func adjust(_ delta: Value) {
        value = min(max(value + delta, range.lowerBound), range.upperBound)
    }
}
