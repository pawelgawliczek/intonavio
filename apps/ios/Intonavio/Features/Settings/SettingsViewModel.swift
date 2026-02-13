import AVFoundation
import Foundation

/// Manages settings: account actions and audio input selection.
@Observable
final class SettingsViewModel {
    var isDeleting = false
    var showDeleteConfirmation = false
    var errorMessage: String?
    var availableInputs: [AVAudioSessionPortDescription] = []
    var selectedInputUID: String?

    func loadAudioInputs() {
        let session = AVAudioSession.sharedInstance()
        availableInputs = session.availableInputs ?? []
        selectedInputUID = session.currentRoute.inputs.first?.uid
    }

    func selectInput(_ port: AVAudioSessionPortDescription) {
        do {
            try AVAudioSession.sharedInstance().setPreferredInput(port)
            selectedInputUID = port.uid
            AppLogger.audio.info("Selected input: \(port.portName)")
        } catch {
            AppLogger.audio.error("Failed to set input: \(error.localizedDescription)")
        }
    }
}
