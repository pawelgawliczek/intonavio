import Foundation

/// Debug-build drift logging for video-audio sync diagnostics.
final class DriftLogger {
    nonisolated(unsafe) static let shared = DriftLogger()

    private var entries: [DriftEntry] = []
    private let maxEntries = 100

    struct DriftEntry {
        let ytTime: Double
        let stemTime: Double
        let drift: Double
        let timestamp: Date
    }

    private init() {}

    func log(ytTime: Double, stemTime: Double, drift: Double) {
        #if DEBUG
        let entry = DriftEntry(
            ytTime: ytTime,
            stemTime: stemTime,
            drift: drift,
            timestamp: Date()
        )
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst()
        }

        if drift > 0.1 {
            let msg = "Drift: yt=\(String(format: "%.3f", ytTime)) "
                + "stem=\(String(format: "%.3f", stemTime)) "
                + "delta=\(String(format: "%.0fms", drift * 1000))"
            AppLogger.sync.debug("\(msg)")
        }
        #endif
    }

    struct DriftStats {
        let avgDrift: Double
        let maxDrift: Double
        let count: Int
    }

    var stats: DriftStats {
        guard !entries.isEmpty else { return DriftStats(avgDrift: 0, maxDrift: 0, count: 0) }
        let drifts = entries.map(\.drift)
        let avg = drifts.reduce(0, +) / Double(drifts.count)
        let maxVal = drifts.max() ?? 0
        return DriftStats(avgDrift: avg, maxDrift: maxVal, count: entries.count)
    }
}
