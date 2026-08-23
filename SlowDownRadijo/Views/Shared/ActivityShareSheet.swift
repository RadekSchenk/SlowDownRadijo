import SwiftUI
import UIKit

/// Wraps `UIActivityViewController` for SwiftUI — used by the Vzkaz tab to
/// hand a recorded voice message off to WhatsApp (or any other share
/// target the user picks) via the system share sheet.
///
/// There's no public API for an app to deliver a file straight into a
/// specific WhatsApp chat automatically — the official WhatsApp Business
/// Cloud API can only send free-form media to a number that has messaged
/// the business first within the last 24 hours, which doesn't hold for an
/// arbitrary first-time listener, and no consumer-facing URL scheme
/// accepts a file attachment. The share sheet is the reliable, approval-free
/// alternative: the user picks WhatsApp, then picks the destination chat
/// themselves inside it — one extra manual step, but it works for anyone,
/// every time, with no Meta Business setup.
struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    /// `true` if the user actually completed handing the item to some
    /// share target (not necessarily WhatsApp specifically — no API
    /// exposes which one they picked), `false` if they dismissed/cancelled.
    var onComplete: (Bool) -> Void = { _ in }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onComplete(completed)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
