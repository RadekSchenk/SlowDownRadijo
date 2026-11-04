import AVFoundation
import AVKit
import SwiftUI

/// The output picker next to the play button, as a pair with it: the
/// same 46pt circle, but quiet — a faint white fill with the AirPlay icon —
/// so play stays the main control. A tap opens the system's picker:
/// Bluetooth and AirPlay speakers, HomePod, Apple TV, a Mac. While the radio
/// plays somewhere other than the phone or wired headphones the icon turns
/// the app's red over a faint red fill. VoiceOver reads where it plays
/// ("Hraje na: JBL Charge 3").
///
/// The picker itself (`AVRoutePickerView`, the only way to open it) lies
/// invisible over the circle and takes the tap.
struct OutputPickerButton: View {
    var diameter: CGFloat = 46

    @ObservedObject private var loc = LocalizationManager.shared
    @State private var output = Output.current()

    var body: some View {
        ZStack {
            Circle()
                .fill(output.isElsewhere ? Theme.liveRed.opacity(0.15) : Theme.hairline(0.08))
            Image(systemName: "airplayaudio")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 20, height: 20)
                .foregroundStyle(output.isElsewhere ? Theme.liveRed : Theme.textPrimary)
        }
        .frame(width: diameter, height: diameter)
        .animation(.easeInOut(duration: 0.25), value: output)
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
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIView(_ picker: AVRoutePickerView, context: Context) {
        picker.accessibilityLabel = label
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, AVRoutePickerViewDelegate {
        func routePickerViewWillBeginPresentingRoutes(_ routePickerView: AVRoutePickerView) {
            // Called on the main thread.
            MainActor.assumeIsolated {
                Analytics.shared.track(.outputPickerOpened(output: AudioOutput.kind()))
            }
        }
    }
}
