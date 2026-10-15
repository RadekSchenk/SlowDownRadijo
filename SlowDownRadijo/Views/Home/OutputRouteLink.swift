import AVFoundation
import AVKit
import SwiftUI

/// "Hraje na: iPhone" under the sleep timer, styled like it (text, then
/// the icon): where the radio plays, and a tap opens the system's output
/// picker — Bluetooth and AirPlay speakers, HomePod, Apple TV, a Mac. The
/// icon turns the app's red while it plays somewhere other than the phone
/// or wired headphones.
///
/// The picker itself (`AVRoutePickerView`, the only way to open it) lies
/// invisible over the row and takes the tap.
struct OutputRouteLink: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var output = Output.current()

    var body: some View {
        HStack(spacing: 8) {
            Text(L10n.playsOn(output.name))
                .font(Theme.Typography.Manrope.bold(size: 14, relativeTo: .subheadline))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            Image(systemName: "airplayaudio")
                .font(.system(size: 13, weight: .bold))
                .frame(width: 15, height: 15)
                .foregroundStyle(output.isElsewhere ? Theme.liveRed : Theme.textPrimary)
        }
        .overlay { InvisibleRoutePicker(label: L10n.playsOn(output.name)) }
        .onReceive(
            NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
                .receive(on: DispatchQueue.main)
        ) { _ in
            output = Output.current()
        }
    }

    struct Output: Equatable {
        let name: String
        let isElsewhere: Bool

        static func current() -> Output {
            guard let port = AVAudioSession.sharedInstance().currentRoute.outputs.first else {
                return Output(name: UIDevice.current.model, isElsewhere: false)
            }
            switch port.portType {
            case .builtInSpeaker, .builtInReceiver:
                // The system calls it "Speaker" in its own language.
                return Output(name: UIDevice.current.model, isElsewhere: false)
            case .headphones:
                return Output(name: port.portName, isElsewhere: false)
            default:
                return Output(name: port.portName, isElsewhere: true)
            }
        }
    }
}

/// `AVRoutePickerView` with its icon hidden, sized to whatever it covers.
private struct InvisibleRoutePicker: UIViewRepresentable {
    let label: String

    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.tintColor = .clear
        picker.activeTintColor = .clear
        picker.prioritizesVideoDevices = false
        picker.backgroundColor = .clear
        picker.accessibilityIdentifier = "airplay"
        return picker
    }

    func updateUIView(_ picker: AVRoutePickerView, context: Context) {
        picker.accessibilityLabel = label
    }
}
