import AVKit
import SwiftUI

/// The system's AirPlay / output picker next to the play button: lists
/// Bluetooth speakers, AirPlay speakers, HomePods, Apple TVs and Macs, and
/// sends the stream there. Muted while playing on the phone, red (the app's
/// accent) while it plays somewhere else — the picker tints itself.
struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.tintColor = UIColor(Theme.mutedText)
        picker.activeTintColor = UIColor(Theme.liveRed)
        picker.prioritizesVideoDevices = false
        picker.backgroundColor = .clear
        picker.accessibilityIdentifier = "airplay"
        return picker
    }

    func updateUIView(_ picker: AVRoutePickerView, context: Context) {}
}
