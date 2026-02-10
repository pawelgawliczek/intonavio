import Foundation

/// Records seek precision measurements for analysis.
/// Tracks the difference between requested and actual
/// seek positions, plus round-trip latency.
final class SeekPrecisionLogger {
    struct Entry {
        let requested: Double
        let actual: Double
        let precisionMs: Double
        let latencyMs: Double
        let timestamp: Date
    }

    private(set) var entries: [Entry] = []

    func record(
        requested: Double,
        actual: Double,
        latencyMs: Double
    ) {
        let precision = abs(actual - requested) * 1000.0
        let entry = Entry(
            requested: requested,
            actual: actual,
            precisionMs: precision,
            latencyMs: latencyMs,
            timestamp: Date()
        )
        entries.append(entry)
    }

    var stats: SeekStats {
        guard !entries.isEmpty else {
            return SeekStats(
                count: 0, avgPrecisionMs: 0,
                maxPrecisionMs: 0,
                percentWithin100ms: 0, avgLatencyMs: 0
            )
        }

        let precisions = entries.map(\.precisionMs)
        let latencies = entries.map(\.latencyMs)
        let within100 = precisions.filter { $0 <= 100 }.count

        return SeekStats(
            count: entries.count,
            avgPrecisionMs: precisions.reduce(0, +)
                / Double(entries.count),
            maxPrecisionMs: precisions.max() ?? 0,
            percentWithin100ms: Double(within100)
                / Double(entries.count) * 100.0,
            avgLatencyMs: latencies.reduce(0, +)
                / Double(entries.count)
        )
    }
}

struct SeekStats {
    let count: Int
    let avgPrecisionMs: Double
    let maxPrecisionMs: Double
    let percentWithin100ms: Double
    let avgLatencyMs: Double
}
