import SwiftUI

/// Difficulty level controlling pitch accuracy thresholds and scoring.
///
/// Beginner has the widest tolerance zones (easiest), Advanced has the
/// tightest (current behavior). Stored in UserDefaults as an integer raw value.
enum DifficultyLevel: Int, CaseIterable, Sendable {
    case beginner = 0
    case intermediate = 1
    case advanced = 2

    /// Read the current difficulty from UserDefaults.
    static var current: DifficultyLevel {
        DifficultyLevel(rawValue: UserDefaults.standard.integer(forKey: "difficultyLevel")) ?? .beginner
    }

    var label: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }

    var description: String {
        switch self {
        case .beginner: return "Wide tolerance zones. Great for warming up or starting out."
        case .intermediate: return "Moderate tolerance. A good balance of challenge and forgiveness."
        case .advanced: return "Tight tolerance zones. For experienced singers seeking precision."
        }
    }

    var icon: String {
        switch self {
        case .beginner: return "star"
        case .intermediate: return "star.leadinghalf.filled"
        case .advanced: return "star.fill"
        }
    }

    // MARK: - Cent Thresholds

    var excellentCents: Float {
        switch self {
        case .beginner: return 150
        case .intermediate: return 75
        case .advanced: return 25
        }
    }

    var goodCents: Float {
        switch self {
        case .beginner: return 300
        case .intermediate: return 150
        case .advanced: return 40
        }
    }

    var fairCents: Float {
        switch self {
        case .beginner: return 450
        case .intermediate: return 225
        case .advanced: return 60
        }
    }

    // MARK: - Point Values

    var excellentPoints: Double {
        100
    }

    var goodPoints: Double {
        switch self {
        case .beginner: return 75
        case .intermediate: return 60
        case .advanced: return 50
        }
    }

    var fairPoints: Double {
        switch self {
        case .beginner: return 40
        case .intermediate: return 25
        case .advanced: return 20
        }
    }

    // MARK: - Zone Definitions

    /// Zone bands for the piano roll renderer (outer-to-inner).
    var zones: [(halfCents: Float, color: Color)] {
        [
            (fairCents, Color.orange.opacity(0.15)),
            (goodCents, Color.yellow.opacity(0.18)),
            (excellentCents, Color.green.opacity(0.22)),
        ]
    }
}
