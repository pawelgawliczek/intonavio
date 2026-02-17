import SwiftUI

/// Transparent overlay that handles touch, drag, momentum, and long-press
/// gestures on the piano roll canvas.
///
/// State machine:
/// ```
/// IDLE → [touch] → TOUCHING (pause, start 1s timer)
///   TOUCHING → [drag > 10pt] → DRAGGING (cancel timer, update offset)
///   TOUCHING → [1s elapsed] → find phrase → setupPhraseLoop
///   TOUCHING → [lift < 1s] → stay paused
///   DRAGGING → [lift] → MOMENTUM (start engine)
///   MOMENTUM → [decay] → seek + resume → IDLE
///   MOMENTUM → [touch] → stop engine → TOUCHING
/// ```
struct PianoRollGestureOverlay: View {
    let gestureState: PianoRollGestureState
    let momentumEngine: PianoRollMomentumEngine
    let canvasWidth: CGFloat
    let currentTime: Double
    let songDuration: Double
    let referenceStore: ReferencePitchStore
    let onPause: () -> Void
    let onSeek: (Double) -> Void
    let onResume: () -> Void
    let onSetupPhraseLoop: (Int) -> Void

    private let windowDuration: Double = 8.0
    private let dragThreshold: CGFloat = 10
    private let longPressDelay: TimeInterval = 1.0
    private let phraseSearchRadius: Double = 2.0

    @State private var longPressTimer: Timer?
    @State private var touchStartLocation: CGPoint = .zero
    @State private var isDragConfirmed = false

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(dragGesture)
    }
}

// MARK: - Gesture

private extension PianoRollGestureOverlay {
    var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                handleDragChanged(value)
            }
            .onEnded { value in
                handleDragEnded(value)
            }
    }

    func handleDragChanged(_ value: DragGesture.Value) {
        let displacement = abs(value.translation.width)

        switch gestureState.phase {
        case .idle, .momentum:
            handleTouchDown(value)

        case .touching:
            if displacement > dragThreshold {
                transitionToDragging(value)
            }

        case .dragging:
            updateBrowseOffset(value)

        case .longPressing:
            break
        }
    }

    func handleDragEnded(_ value: DragGesture.Value) {
        cancelLongPressTimer()

        switch gestureState.phase {
        case .touching:
            // Short tap — stay paused at current position
            gestureState.phase = .idle

        case .dragging:
            transitionToMomentum(value)

        case .longPressing, .idle, .momentum:
            gestureState.phase = .idle
        }
    }
}

// MARK: - Phase Transitions

private extension PianoRollGestureOverlay {
    func handleTouchDown(_ value: DragGesture.Value) {
        if momentumEngine.isRunning {
            momentumEngine.stop()
        }

        gestureState.startBrowsing(at: currentTime)
        gestureState.phase = .touching
        touchStartLocation = value.startLocation
        isDragConfirmed = false

        onPause()
        triggerHaptic(.light)
        startLongPressTimer(at: value.startLocation)
    }

    func transitionToDragging(_ value: DragGesture.Value) {
        cancelLongPressTimer()
        isDragConfirmed = true
        gestureState.phase = .dragging
        updateBrowseOffset(value)
    }

    func updateBrowseOffset(_ value: DragGesture.Value) {
        guard canvasWidth > 0 else { return }
        let rawOffset = -(Double(value.translation.width) / Double(canvasWidth))
            * windowDuration
        let displayTime = gestureState.browseAnchorTime + rawOffset
        let clamped = max(0, min(displayTime, songDuration))
        gestureState.browseOffset = clamped - gestureState.browseAnchorTime
    }

    func transitionToMomentum(_ value: DragGesture.Value) {
        guard canvasWidth > 0 else {
            onResume()
            return
        }

        let predictedDelta = value.predictedEndTranslation.width
            - value.translation.width
        let velocity = -(Double(predictedDelta) / Double(canvasWidth))
            * windowDuration / 60.0

        guard abs(velocity) > 0.001 else {
            onResume()
            return
        }

        gestureState.phase = .momentum

        momentumEngine.start(
            velocity: velocity,
            onUpdate: { [gestureState, songDuration] delta in
                let newOffset = gestureState.browseOffset + delta
                let displayTime = gestureState.browseAnchorTime + newOffset
                let clamped = max(0, min(displayTime, songDuration))
                gestureState.browseOffset = clamped
                    - gestureState.browseAnchorTime
            },
            onComplete: { [onResume] in
                onResume()
            }
        )
    }
}

// MARK: - Long Press

private extension PianoRollGestureOverlay {
    func startLongPressTimer(at location: CGPoint) {
        cancelLongPressTimer()
        longPressTimer = Timer.scheduledTimer(
            withTimeInterval: longPressDelay,
            repeats: false
        ) { [gestureState] _ in
            MainActor.assumeIsolated {
                guard gestureState.phase == .touching else { return }
                gestureState.phase = .longPressing
                handleLongPress(at: location)
            }
        }
    }

    func cancelLongPressTimer() {
        longPressTimer?.invalidate()
        longPressTimer = nil
    }

    func handleLongPress(at location: CGPoint) {
        let touchTime = touchPositionToTime(x: location.x)

        if let phrase = findPhrase(near: touchTime) {
            triggerHaptic(.medium)
            onSetupPhraseLoop(phrase.index)
        } else {
            triggerHaptic(.rigid)
        }

        gestureState.phase = .idle
    }

    func touchPositionToTime(x: CGFloat) -> Double {
        let displayTime = gestureState.displayTime(playbackTime: currentTime)
        let windowStart = displayTime - windowDuration / 2
        return windowStart + (Double(x) / Double(canvasWidth)) * windowDuration
    }

    func findPhrase(near time: Double) -> ReferencePhraseInfo? {
        if let exact = referenceStore.phrase(at: time) {
            return exact
        }
        // Search within +-2 seconds for nearest phrase
        let candidates = referenceStore.phrases.filter { phrase in
            let distance = min(
                abs(phrase.startTime - time),
                abs(phrase.endTime - time)
            )
            return distance <= phraseSearchRadius
        }
        return candidates.min { a, b in
            let distA = min(abs(a.startTime - time), abs(a.endTime - time))
            let distB = min(abs(b.startTime - time), abs(b.endTime - time))
            return distA < distB
        }
    }
}

// MARK: - Haptics

private extension PianoRollGestureOverlay {
    func triggerHaptic(_ style: HapticStyle) {
        #if os(iOS)
        switch style {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .rigid:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }
        #endif
    }

    enum HapticStyle {
        case light, medium, rigid
    }
}
