import Foundation

/// Loop state machine per docs/07-youtube-looping.md:
/// Idle -> Playing -> SettingA -> SettingAB -> Looping
enum LoopState: String, Sendable {
    case idle
    case playing
    case settingA
    case settingAB
    case looping
    case paused
}
