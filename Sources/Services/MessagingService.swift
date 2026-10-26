import Foundation
import MessageUI
import SwiftUI

enum MessagingService {
    @MainActor
    static var canSendText: Bool {
        MFMessageComposeViewController.canSendText()
    }

    static func reminderBody(clientName: String, sessionDate: Date) -> String {
        let day = Calendar.current.isDateInTomorrow(sessionDate)
            ? "tomorrow"
            : sessionDate.formatted(date: .abbreviated, time: .omitted)
        let time = sessionDate.formatted(date: .omitted, time: .shortened)
        let firstName = clientName.split(separator: " ").first.map(String.init) ?? clientName
        return "Hi \(firstName), reminder: our session \(day) at \(time) — see you then!"
    }
}

/// SwiftUI wrapper for the system SMS compose sheet. iOS requires the user to
/// tap Send themselves — there is no API for automated sending.
struct MessageComposeView: UIViewControllerRepresentable {
    let recipient: String
    let body: String

    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: { dismiss() })
    }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.recipients = [recipient]
        controller.body = body
        controller.messageComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    /// The delegate protocol is nonisolated, so the coordinator cannot itself be
    /// main-actor bound. MessageUI always calls back on the main thread, which
    /// `assumeIsolated` asserts before touching main-actor UIKit and SwiftUI state.
    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinish: @MainActor () -> Void

        init(onFinish: @escaping @MainActor () -> Void) {
            self.onFinish = onFinish
        }

        func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            let onFinish = onFinish  // don't capture the non-Sendable coordinator
            MainActor.assumeIsolated {
                controller.dismiss(animated: true)
                onFinish()
            }
        }
    }
}
