import AVFoundation

/// What kind of output the audio goes to, for analytics: the kind only,
/// never the device's name ("Radkův HomePod" would lead to a person).
enum AudioOutput {
    /// "phone", "wired", "bluetooth", "airplay", "carplay", "hdmi" or "other".
    static func kind() -> String {
        guard let port = AVAudioSession.sharedInstance().currentRoute.outputs.first else { return "phone" }
        switch port.portType {
        case .builtInSpeaker, .builtInReceiver: return "phone"
        case .headphones, .usbAudio, .lineOut: return "wired"
        case .bluetoothA2DP, .bluetoothLE, .bluetoothHFP: return "bluetooth"
        case .airPlay: return "airplay"
        case .carAudio: return "carplay"
        case .HDMI: return "hdmi"
        default: return "other"
        }
    }
}
