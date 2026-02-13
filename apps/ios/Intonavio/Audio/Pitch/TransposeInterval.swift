import Foundation

/// Musical intervals for transposing the reference pitch graph.
/// Raw value is the semitone offset applied to MIDI notes.
enum TransposeInterval: Int, CaseIterable, Identifiable {
    case twoOctavesDown = -24
    case octaveDown = -12
    case fifthDown = -7
    case fourthDown = -5
    case majorThirdDown = -4
    case minorThirdDown = -3
    case unison = 0
    case minorThirdUp = 3
    case majorThirdUp = 4
    case fourthUp = 5
    case fifthUp = 7
    case octaveUp = 12
    case twoOctavesUp = 24

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .twoOctavesDown: return "-2 oct"
        case .octaveDown: return "-1 oct"
        case .fifthDown: return "-5th"
        case .fourthDown: return "-4th"
        case .majorThirdDown: return "-M3"
        case .minorThirdDown: return "-m3"
        case .unison: return "0"
        case .minorThirdUp: return "+m3"
        case .majorThirdUp: return "+M3"
        case .fourthUp: return "+4th"
        case .fifthUp: return "+5th"
        case .octaveUp: return "+1 oct"
        case .twoOctavesUp: return "+2 oct"
        }
    }
}
