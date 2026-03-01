import SwiftData
import SwiftUI

#if os(iOS)
import AVFoundation
#endif

@main
struct IntonavioApp: App {
    @State private var appState = AppState()
    @AppStorage("appTheme") private var themeRaw = AppTheme.dark.rawValue

    init() {
        #if os(iOS)
        configureAudioSession()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .modelContainer(for: ScoreRecord.self)
                .preferredColorScheme(.dark)
        }
        #if os(macOS)
        .defaultSize(width: 1200, height: 800)
        #endif
    }
}

// MARK: - Audio Session (iOS)

#if os(iOS)
private extension IntonavioApp {
    func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
            )
            try session.setActive(true)
            AppLogger.audio.info("AVAudioSession configured")
        } catch {
            AppLogger.audio.error(
                "AVAudioSession setup failed: \(error.localizedDescription)"
            )
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { notification in
            handleInterruption(notification)
        }
    }

    func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }

        switch type {
        case .began:
            AppLogger.audio.info("Audio session interrupted")
        case .ended:
            let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                AppLogger.audio.info("Audio session interruption ended, resuming")
            }
        @unknown default:
            break
        }
    }
}
#endif
