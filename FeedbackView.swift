import SwiftUI
import MessageUI

struct FeedbackView: View {
    @Environment(\.openURL) private var openURL
    @State private var feedback = ""
    @State private var replyEmail = ""
    @State private var isShowingMailComposer = false

    private let recipient = "creecyinc@gmail.com"

    var body: some View {
        Form {
            FeedbackMessageSection(feedback: $feedback)
            FeedbackContactSection(replyEmail: $replyEmail)

            Section {
                Button {
                    sendFeedback()
                } label: {
                    Label("Review Email", systemImage: "paperplane")
                }
                .disabled(trimmedFeedback.isEmpty)
                .accessibilityIdentifier("reviewFeedbackEmailButton")
            } footer: {
                Text("You’ll have a chance to review the message before sending it.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackgroundView(tab: .more))
        .navigationTitle("Share Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .formStyle(.grouped)
        .sheet(isPresented: $isShowingMailComposer) {
            FeedbackMailComposer(
                recipient: recipient,
                subject: "The Bible App Feedback",
                messageBody: messageBody
            )
        }
    }

    private var trimmedFeedback: String {
        feedback.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedReplyEmail: String {
        replyEmail.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var messageBody: String {
        let contact = trimmedReplyEmail.isEmpty ? "Not provided" : trimmedReplyEmail

        return """
        Feedback:
        \(trimmedFeedback)

        Preferred reply email:
        \(contact)
        """
    }

    private func sendFeedback() {
        if MFMailComposeViewController.canSendMail() {
            isShowingMailComposer = true
        } else if let fallbackURL {
            openURL(fallbackURL)
        }
    }

    private var fallbackURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: "The Bible App Feedback"),
            URLQueryItem(name: "body", value: messageBody)
        ]
        return components.url
    }
}

private struct FeedbackMessageSection: View {
    @Binding var feedback: String

    var body: some View {
        Section {
            TextEditor(text: $feedback)
                .frame(minHeight: 160)
                .overlay(alignment: .topLeading) {
                    if feedback.isEmpty {
                        Text("Share feedback, report bugs, request features...or just say hi!")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
                .accessibilityLabel("Feedback")
                .accessibilityIdentifier("feedbackMessageEditor")
        } header: {
            Text("Your Feedback")
        } footer: {
            Text("Tell us what you like, what could be improved, or report a problem.")
        }
    }
}

private struct FeedbackContactSection: View {
    @Binding var replyEmail: String

    var body: some View {
        Section {
            TextField("Email address", text: $replyEmail)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("feedbackReplyEmailField")
        } header: {
            Text("Reply Email (Optional)")
        } footer: {
            Text("Leave this blank if you don’t want a response.")
        }
    }
}

private struct FeedbackMailComposer: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let messageBody: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients([recipient])
        composer.setSubject(subject)
        composer.setMessageBody(messageBody, isHTML: false)
        return composer
    }

    func updateUIViewController(
        _ uiViewController: MFMailComposeViewController,
        context: Context
    ) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            controller.dismiss(animated: true)
        }
    }
}

#Preview {
    NavigationStack {
        FeedbackView()
    }
}
