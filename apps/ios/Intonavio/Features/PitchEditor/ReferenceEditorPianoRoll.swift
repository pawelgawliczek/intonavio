import SwiftUI

/// Read-only piano roll preview for the reference editor. Shows a fixed
/// window around the selected range (or origin if no range) and overlays
/// a translucent highlight over the selection.
struct ReferenceEditorPianoRoll: View {
    let viewModel: ReferenceEditorViewModel

    @State private var mode: VisualizationMode = .zonesLine

    private var centerTime: Double {
        if let start = viewModel.rangeStart, let end = viewModel.rangeEnd {
            return (start + end) / 2
        }
        return viewModel.rangeStart ?? 0
    }

    private var windowFrames: ArraySlice<ReferencePitchFrame> {
        let frames = viewModel.previewFrames
        guard viewModel.hopDuration > 0, !frames.isEmpty else { return [][...] }
        let windowStart = max(0, centerTime - 4.0)
        let windowEnd = centerTime + 4.0
        let lo = max(0, Int(windowStart / viewModel.hopDuration))
        let hi = min(frames.count - 1, Int(windowEnd / viewModel.hopDuration))
        guard lo <= hi else { return [][...] }
        return frames[lo...hi]
    }

    private var midiRange: (min: Float, max: Float) {
        let voiced = viewModel.previewFrames.compactMap { frame -> Float? in
            guard frame.isVoiced, frame.isAudible, let midi = frame.midiNote else { return nil }
            return Float(midi)
        }
        guard let minVal = voiced.min(), let maxVal = voiced.max() else {
            return (48, 72)
        }
        return (minVal - 3, maxVal + 3)
    }

    var body: some View {
        ZStack {
            PianoRollView(
                mode: $mode,
                referenceFrames: windowFrames,
                hopDuration: viewModel.hopDuration,
                detectedPoints: [],
                currentTime: centerTime,
                currentNoteName: nil,
                centsDeviation: 0,
                accuracy: .unvoiced,
                score: 0,
                isPitchReady: !viewModel.previewFrames.isEmpty,
                midiMin: midiRange.min,
                midiMax: midiRange.max,
                transposeSemitones: 0,
                zones: DifficultyLevel.current.zones
            )
            if viewModel.hasRange {
                rangeOverlay
            }
        }
    }

    private var rangeOverlay: some View {
        GeometryReader { geometry in
            let windowStart = max(0, centerTime - 4.0)
            let windowEnd = centerTime + 4.0
            let windowSpan = windowEnd - windowStart
            let start = max(viewModel.rangeStart ?? 0, windowStart)
            let end = min(viewModel.rangeEnd ?? 0, windowEnd)
            if end > start, windowSpan > 0 {
                let x = (start - windowStart) / windowSpan * geometry.size.width
                let w = (end - start) / windowSpan * geometry.size.width
                Rectangle()
                    .fill(Color.intonavioAmber.opacity(0.18))
                    .overlay(
                        Rectangle()
                            .stroke(Color.intonavioAmber.opacity(0.6), lineWidth: 1)
                    )
                    .frame(width: w)
                    .position(x: x + w / 2, y: geometry.size.height / 2)
                    .allowsHitTesting(false)
            }
        }
    }
}
