import SwiftUI

/// Accuracy classification based on cents deviation from reference.
enum PitchAccuracy: Sendable {
    case excellent  // ±10 cents -> 100 points
    case good       // ±20 cents ->  50 points
    case fair       // ±30 cents ->  20 points
    case poor       // >30 cents ->   0 points
    case unvoiced   // No pitch detected

    /// Classify based on absolute cents deviation.
    static func classify(cents: Float) -> PitchAccuracy {
        let absCents = abs(cents)
        if absCents <= 10 { return .excellent }
        if absCents <= 20 { return .good }
        if absCents <= 30 { return .fair }
        return .poor
    }

    var points: Double {
        switch self {
        case .excellent: return 100
        case .good: return 50
        case .fair: return 20
        case .poor: return 0
        case .unvoiced: return 0
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
