import Foundation

/// Piano roll visualization mode selector.
enum VisualizationMode: String, CaseIterable, Identifiable, Sendable {
    case zonesLine = "Zones"
    case twoLines = "Lines"
    case zonesGlow = "Glow"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .zonesLine: return "Reference zones + detected line"
        case .twoLines: return "Reference line + detected line"
        case .zonesGlow: return "Reference zones + glowing trail"
        }
    }
}
