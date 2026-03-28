import OSLog

/// Centralized logging via os.Logger. All modules use this
/// instead of print() to enable structured logging and filtering.
enum AppLogger {
    static let auth = Logger(subsystem: subsystem, category: "Auth")
    static let network = Logger(subsystem: subsystem, category: "Network")
    static let player = Logger(subsystem: subsystem, category: "Player")
    static let audio = Logger(subsystem: subsystem, category: "Audio")
    static let sync = Logger(subsystem: subsystem, category: "Sync")
    static let library = Logger(subsystem: subsystem, category: "Library")
    static let sessions = Logger(subsystem: subsystem, category: "Sessions")
    static let pitch = Logger(subsystem: subsystem, category: "Pitch")
    static let recording = Logger(subsystem: subsystem, category: "Recording")
    static let lyrics = Logger(subsystem: subsystem, category: "Lyrics")
    static let general = Logger(subsystem: subsystem, category: "General")

    private static let subsystem = Bundle.main.bundleIdentifier
        ?? "com.intonavio.app"
}
