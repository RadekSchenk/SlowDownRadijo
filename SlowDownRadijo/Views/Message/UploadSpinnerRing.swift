import SwiftUI

/// A continuously-rotating partial ring, matching the Figma "sending"
/// state's spinner — indeterminate (we don't track real upload byte
/// progress, the recording is small enough to upload in well under a
/// second on any real connection), so this only communicates "in
/// progress," not a literal percentage.
struct UploadSpinnerRing: View {
    @State private var rotation: Double = 0

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.25)
            .stroke(Theme.sunOrange, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            .frame(width: 120, height: 120)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}
