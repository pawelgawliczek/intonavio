import Foundation

/// Timer-based deceleration engine for piano roll momentum scrolling.
///
/// Runs at ~60fps, applying friction each frame until velocity decays
/// below a threshold. Calls `onUpdate` with incremental time deltas
/// and `onComplete` when momentum finishes.
@MainActor @Observable
final class PianoRollMomentumEngine {
    private var displayLink: Timer?
    private var velocity: Double = 0
    private var onUpdate: ((Double) -> Void)?
    private var onComplete: (() -> Void)?

    private let friction: Double = 0.95
    private let stopThreshold: Double = 0.01
    private let frameInterval: TimeInterval = 1.0 / 60.0

    var isRunning: Bool { displayLink != nil }

    /// Start momentum with an initial velocity (seconds per frame).
    /// - Parameters:
    ///   - velocity: Initial scroll velocity in seconds-of-audio per frame.
    ///   - onUpdate: Called each frame with the incremental time delta.
    ///   - onComplete: Called when velocity decays below threshold.
    func start(
        velocity: Double,
        onUpdate: @escaping (Double) -> Void,
        onComplete: @escaping () -> Void
    ) {
        stop()
        self.velocity = velocity
        self.onUpdate = onUpdate
        self.onComplete = onComplete

        displayLink = Timer.scheduledTimer(
            withTimeInterval: frameInterval,
            repeats: true
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    /// Stop the engine immediately, discarding remaining momentum.
    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        velocity = 0
        onUpdate = nil
        onComplete = nil
    }

    private func tick() {
        velocity *= friction
        if abs(velocity) < stopThreshold {
            let completion = onComplete
            stop()
            completion?()
            return
        }
        onUpdate?(velocity)
    }
}
