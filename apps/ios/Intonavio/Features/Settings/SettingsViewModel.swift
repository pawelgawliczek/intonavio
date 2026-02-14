import AVFoundation
import Foundation

/// Manages settings: account actions and audio input selection.
@Observable
final class SettingsViewModel {
    var isDeleting = false
    var showDeleteConfirmation = false
    var errorMessage: String?
    var selectedInputUID: String?

    #if os(iOS)
    var availableInputs: [AVAudioSessionPortDescription] = []
    #else
    var availableDevices: [AVCaptureDevice] = []
    #endif

    func loadAudioInputs() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        availableInputs = session.availableInputs ?? []
        selectedInputUID = session.currentRoute.inputs.first?.uid
        #else
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        )
        availableDevices = discovery.devices
        selectedInputUID = AVCaptureDevice.default(for: .audio)?.uniqueID
        #endif
    }

    #if os(iOS)
    func selectInput(_ port: AVAudioSessionPortDescription) {
        do {
            try AVAudioSession.sharedInstance().setPreferredInput(port)
            selectedInputUID = port.uid
            AppLogger.audio.info("Selected input: \(port.portName)")
        } catch {
            AppLogger.audio.error("Failed to set input: \(error.localizedDescription)")
        }
    }
    #else
    func selectDevice(_ device: AVCaptureDevice) {
        selectedInputUID = device.uniqueID
        AppLogger.audio.info("Selected input: \(device.localizedName)")
    }
    #endif
}
