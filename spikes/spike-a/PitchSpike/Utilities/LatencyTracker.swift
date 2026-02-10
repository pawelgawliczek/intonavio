import Foundation

/// Tracks latency measurements in a fixed-size ring buffer
/// and provides min/max/avg/p95 statistics.
final class LatencyTracker: @unchecked Sendable {
    private let capacity: Int
    private var samples: [Double]
    private var index: Int = 0
    private var count: Int = 0
    private let lock = NSLock()

    init(capacity: Int = 200) {
        self.capacity = capacity
        self.samples = Array(repeating: 0, count: capacity)
    }

    func record(_ latencyMs: Double) {
        lock.lock()
        defer { lock.unlock() }
        samples[index] = latencyMs
        index = (index + 1) % capacity
        if count < capacity { count += 1 }
    }

    var stats: LatencyStats {
        lock.lock()
        defer { lock.unlock() }
        guard count > 0 else {
            return LatencyStats(min: 0, max: 0, avg: 0, p95: 0, count: 0)
        }
        let active = Array(samples.prefix(count)).sorted()
        let sum = active.reduce(0, +)
        let p95Index = min(Int(Double(count) * 0.95), count - 1)
        return LatencyStats(
            min: active.first ?? 0,
            max: active.last ?? 0,
            avg: sum / Double(count),
            p95: active[p95Index],
            count: count
        )
    }
}

struct LatencyStats {
    let min: Double
    let max: Double
    let avg: Double
    let p95: Double
    let count: Int
}
