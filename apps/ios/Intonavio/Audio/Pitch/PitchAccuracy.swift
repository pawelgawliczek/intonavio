import SwiftUI

/// Accuracy classification based on cents deviation from reference.
enum PitchAccuracy: Sendable {
    case excellent  // ±10 cents -> 100 points
    case good       // ±25 cents ->  75 points
    case fair       // ±50 cents ->  50 points
    case poor       // >50 cents ->   0 points
    case unvoiced   // No pitch detected

    /// Classify based on absolute cents deviation.
    static func classify(cents: Float) -> PitchAccuracy {
        let absCents = abs(cents)
        if absCents <= 10 { return .excellent }
        if absCents <= 25 { return .good }
        if absCents <= 50 { return .fair }
        return .poor
    }

    var points: Double {
        switch self {
        case .excellent: return 100
        case .good: return 75
        case .fair: return 50
        case .poor: return 0
        case .unvoiced: return 0
        }
    }

    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return Color(red: 0.6, green: 0.8, blue: 0.2)
        case .fair: return .yellow
        case .poor: return .red
        case .unvoiced: return .gray
        }
    }

    var label: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        case .unvoiced: return "—"
        }
    }
}
