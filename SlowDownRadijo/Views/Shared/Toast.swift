import SwiftUI
import UIKit

/// One short message at the bottom of the screen ("Dáme ti vědět, až
/// začne …"), optionally with an action. Shown via `ToastCenter.shared`
/// and drawn by `.toastOverlay()` on the tab view and the menu sheet.
@MainActor
final class ToastCenter: ObservableObject {
    static let shared = ToastCenter()

    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let systemImage: String
        let message: String
        var actionTitle: String? = nil
        var action: (() -> Void)? = nil

        static func == (lhs: Toast, rhs: Toast) -> Bool { lhs.id == rhs.id }
    }

    @Published private(set) var current: Toast?
    private var dismissTask: Task<Void, Never>?

    func show(_ toast: Toast) {
        current = toast
        UIAccessibility.post(notification: .announcement, argument: toast.message)
        dismissTask?.cancel()
        // A little longer when there's something to tap.
        let seconds: Double = toast.action == nil ? 3 : 5
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, self?.current?.id == toast.id else { return }
            self?.current = nil
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        current = nil
    }
}

/// Library P22 — toast open / close: rises from its bottom edge out of a
/// 2px blur (`.reveal`) on the 350ms smooth-out curve.
private struct ToastOverlay: ViewModifier {
    @ObservedObject private var center = ToastCenter.shared

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            ZStack {
                if let toast = center.current {
                    ToastView(toast: toast)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                        .transition(.reveal)
                }
            }
            .animation(Motion.smoothOut(Motion.medium), value: center.current?.id)
        }
    }
}

extension View {
    func toastOverlay() -> some View {
        modifier(ToastOverlay())
    }
}

private struct ToastView: View {
    let toast: ToastCenter.Toast

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.systemImage)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.liveRed)
                .frame(width: 20)

            Text(toast.message)
                .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .subheadline))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let actionTitle = toast.actionTitle, let action = toast.action {
                Button {
                    action()
                    ToastCenter.shared.dismiss()
                } label: {
                    Text(actionTitle)
                        .font(Theme.Typography.Manrope.extraBold(size: 14, relativeTo: .subheadline))
                        .foregroundStyle(Theme.liveRed)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Theme.statsCardRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Theme.hairline(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
        .onTapGesture { ToastCenter.shared.dismiss() }
    }
}
