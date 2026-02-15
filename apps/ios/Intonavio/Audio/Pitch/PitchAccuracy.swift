import SwiftUI

/// Accuracy classification based on cents deviation from reference.
enum PitchAccuracy: Sendable {
    case excellent  // Perfect — tightest zone
    case good       // Good — middle zone
    case fair       // OK — outer zone
    case poor       // Miss — outside all zones
    case unvoiced   // No pitch detected

    /// Classify based on absolute cents deviation.
    static func classify(cents: Float, difficulty: DifficultyLevel = .current) -> PitchAccuracy {
        let absCents = abs(cents)
        if absCents <= difficulty.excellentCents { return .excellent }
        if absCents <= difficulty.goodCents { return .good }
        if absCents <= difficulty.fairCents { return .fair }
        return .poor
    }

    /// Points awarded for this accuracy at the given difficulty.
    func points(difficulty: DifficultyLevel = .current) -> Double {
        switch self {
        case .excellent: return difficulty.excellentPoints
        case .good: return difficulty.goodPoints
        case .fair: return difficulty.fairPoints
        case .poor, .unvoiced: return 0
        }
    }

    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .yellow
        case .fair: return .orange
        case .poor: return .gray.opacity(0.5)
        case .unvoiced: return .gray
        }
    }

    var label: String {
        switch self {
        case .excellent: return "Perfect"
        case .good: return "Good"
        case .fair: return "OK"
        case .poor: return "Miss"
        case .unvoiced: return "—"
        }
    }
}
