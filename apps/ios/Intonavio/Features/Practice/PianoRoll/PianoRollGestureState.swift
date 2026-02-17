import Foundation

/// Tracks the interaction phase for piano roll gestures.
enum InteractionPhase {
    case idle
    case touching
    case dragging
    case momentum
    case longPressing
}

/// Observable state for piano roll browsing mode.
///
/// When browsing, the displayed time on the canvas is decoupled from
/// the actual playback time, allowing the user to scrub freely.
@MainActor @Observable
final class PianoRollGestureState {
    var isBrowsing = false
    var browseOffset: Double = 0
    var browseAnchorTime: Double = 0
    var phase: InteractionPhase = .idle

    /// Returns the time to display on the canvas.
    /// When browsing, returns the anchor + offset; otherwise returns playback time.
    func displayTime(playbackTime: Double) -> Double {
        guard isBrowsing else { return playbackTime }
        return browseAnchorTime + browseOffset
    }

    /// Enter browsing mode, anchoring at the current playback time.
    func startBrowsing(at playbackTime: Double) {
        guard !isBrowsing else { return }
        isBrowsing = true
        browseAnchorTime = playbackTime
        browseOffset = 0
    }

    /// Exit browsing mode and reset offsets.
    func exitBrowsing() {
        isBrowsing = false
        browseOffset = 0
        browseAnchorTime = 0
        phase = .idle
    }
}
