import AVFoundation
import SwiftUI

/// Manages onboarding state: step progression, mic permission,
/// headphone detection, and pitch test audio engine lifecycle.
@Observable
final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case welcome = 0
        case headphones = 1
        case micPermission = 2
        case pitchTest = 3
        case addSong = 4
    }

    var currentStep: Step = .welcome
    var headphonesDetected = false
    var micPermissionGranted = false
    var micPermissionDenied = false
    var detectedNoteName: String?

    private var audioEngine: AudioEngine?
    private var pitchDetector: PitchDetector?

    #if os(iOS)
    private var routeObserver: NSObjectProtocol?
    #endif

    // MARK: - Navigation

    func advance() {
        guard let next = Step(rawValue: currentStep.rawValue + 1) else {
            return
        }

        // Skip pitch test if mic was denied
        if next == .pitchTest && micPermissionDenied {
            currentStep = .addSong
            return
        }

        currentStep = next
    }

    // MARK: - Headphone Detection

    func checkHeadphones() {
        #if os(iOS)
        let route = AVAudioSession.sharedInstance().currentRoute
        headphonesDetected = route.outputs.contains { output in
            [.headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE]
                .contains(output.portType)
        }
        observeRouteChanges()
        #else
        headphonesDetected = false
        #endif
    }

    // MARK: - Microphone Permission

    func requestMicPermission() {
        #if os(iOS)
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.micPermissionGranted = granted
                self?.micPermissionDenied = !granted
            }
        }
        #else
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                self?.micPermissionGranted = granted
                self?.micPermissionDenied = !granted
            }
        }
        #endif
    }

    // MARK: - Pitch Test

    func startPitchTest() {
        let engine = AudioEngine()
        let detector = PitchDetector(engine: engine)

        detector.onPitchDetected = { [weak self] result in
            self?.detectedNoteName = result.noteName
        }

        do {
            try detector.start()
        } catch {
            AppLogger.pitch.error(
                "Onboarding pitch test failed to start: \(error.localizedDescription)"
            )
            return
        }

        self.audioEngine = engine
        self.pitchDetector = detector
    }

    func stopPitchTest() {
        pitchDetector?.stop()
        audioEngine?.shutdown()
        pitchDetector = nil
        audioEngine = nil
        detectedNoteName = nil
    }

    // MARK: - Completion

    static let hasCompletedKey = "hasCompletedOnboarding"

    static var hasCompleted: Bool {
        UserDefaults.standard.bool(forKey: hasCompletedKey)
    }

    func complete() {
        stopPitchTest()
        cleanupObservers()
        UserDefaults.standard.set(true, forKey: Self.hasCompletedKey)
    }

    static func reset() {
        UserDefaults.standard.set(false, forKey: hasCompletedKey)
    }

    deinit {
        pitchDetector?.stop()
        audioEngine?.shutdown()
        cleanupObservers()
    }
}

// MARK: - Route Observation

private extension OnboardingViewModel {
    #if os(iOS)
    func observeRouteChanges() {
        cleanupObservers()
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] _ in
            self?.checkHeadphones()
        }
    }
    #endif

    func cleanupObservers() {
        #if os(iOS)
        if let observer = routeObserver {
            NotificationCenter.default.removeObserver(observer)
            routeObserver = nil
        }
        #endif
    }
}
