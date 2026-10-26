import SwiftUI
#if os(iOS)
import MessageUI
import UIKit

struct SendActions: View {
    let text: String
    @State private var isTexting = false
    @State private var isSharing = false
    @State private var isCalling = false
    @State private var feedback: String?
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .subheadline) private var tilePadding: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("Send or call").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
            let layout = typeSize >= .accessibility1 ? AnyLayout(VStackLayout(spacing: Theme.Space.sm))
                                                     : AnyLayout(HStackLayout(spacing: Theme.Space.sm))
            layout {
                action("Text it", "message.fill", id: "send-text", perform: textIt)
                action("Share", "square.and.arrow.up", id: "send-share") { isSharing = true }
                action("Call", "phone.fill", id: "send-call") { isCalling = true }
            }
            Text("You choose who it goes to and confirm before anything is sent or dialed.")
                .font(.footnote).foregroundStyle(Theme.textSecondary)
            if let feedback { Text(feedback).font(.subheadline).foregroundStyle(Theme.textSecondary) }
        }
        .sheet(isPresented: $isTexting) {
            MessageComposer(body: text) { isTexting = false }.ignoresSafeArea()
        }
        .sheet(isPresented: $isSharing) {
            ActivitySheet(items: [text]).ignoresSafeArea()
        }
        .sheet(isPresented: $isCalling) {
            CallSheet()
        }
    }

    private func action(_ title: String, _ symbol: String, id: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            VStack(spacing: 6) {
                Image(systemName: symbol).font(.title3.weight(.semibold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Theme.accent)
            .padding(tilePadding)
            .frame(maxWidth: .infinity, minHeight: 68)
            .background(Theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        }
        .buttonStyle(PressScaleStyle())
        .accessTarget(id, label: title, order: 13, action: perform)
    }

    private func textIt() {
        if MFMessageComposeViewController.canSendText() {
            isTexting = true
        } else {
            feedback = "Text messages are unavailable on this device. Choose Share to use another app."
        }
    }
}

private struct MessageComposer: UIViewControllerRepresentable {
    let body: String
    let onFinish: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.body = body
        controller.messageComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: MFMessageComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

        func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                          didFinishWith result: MessageComposeResult) {
            onFinish()
        }
    }
}

private struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct CallSheet: View {
    @State private var number = ""
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    init(number: String = "") {
        _number = State(initialValue: number)
    }

    private var digits: String {
        number.filter { $0.isNumber || $0 == "+" }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Phone number", text: $number)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .font(.title2.weight(.semibold))
                        .focused($focused)
                        .frame(minHeight: 52)
                        .accessTarget("number", label: "Phone number") { focused = true }
                } footer: {
                    Text("iPhone asks you to confirm before it calls.")
                }
            }
            .navigationTitle("Call someone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                Button("Call") { call() }
                    .buttonStyle(.pill)
                    .disabled(digits.count < 3)
                    .padding(Theme.gutter)
                    .background(.bar)
                    .accessTarget("call", label: "Call", order: 10) { call() }
            }
            .onAppear { focused = true }
        }
        .tint(Theme.accent)
    }

    private func call() {
        guard digits.count >= 3, let url = URL(string: "tel:\(digits)") else { return }
        openURL(url)
        dismiss()
    }
}
#endif
