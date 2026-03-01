import SwiftUI

/// SwiftUI Canvas that draws the piano roll: grid, reference pitch, detected pitch.
struct PianoRollCanvas: View {
    let mode: VisualizationMode
    let referenceFrames: ArraySlice<ReferencePitchFrame>
    let hopDuration: Double
    let detectedPoints: [DetectedPitchPoint]
    let currentTime: Double
    let midiMin: Float
    let midiMax: Float
    let transposeSemitones: Int
    let zones: [(halfCents: Float, color: Color)]
    /// Actual playback time when browsing (nil when not browsing).
    var playbackTime: Double?
    var isBrowsing: Bool = false

    /// 8-second scrolling window: 4s past + 4s future.
    private let windowDuration: Double = 8.0

    private var timeRange: ClosedRange<Double> {
        let start = currentTime - windowDuration / 2
        let end = currentTime + windowDuration / 2
        return start...end
    }

    private var midiRange: ClosedRange<Float> {
        midiMin...midiMax
    }

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)

            PianoRollRenderer.drawGrid(
                context: &context,
                rect: rect,
                midiRange: midiRange,
                isBrowsing: isBrowsing
            )

            if isBrowsing, let pbTime = playbackTime {
                drawPlaybackIndicator(
                    context: &context,
                    rect: rect,
                    playbackTime: pbTime
                )
            }

            let offset = Float(transposeSemitones)

            switch mode {
            case .zonesLine:
                PianoRollRenderer.drawReferenceZones(
                    context: &context,
                    frames: referenceFrames,
                    hopDuration: hopDuration,
                    rect: rect,
                    timeRange: timeRange,
                    midiRange: midiRange,
                    transposeOffset: offset,
                    zones: zones
                )
                PianoRollRenderer.drawReferenceLine(
                    context: &context,
                    frames: referenceFrames,
                    hopDuration: hopDuration,
                    rect: rect,
                    timeRange: timeRange,
                    midiRange: midiRange,
                    transposeOffset: offset
                )
                PianoRollRenderer.drawDetectedLine(
                    context: &context,
                    points: detectedPoints,
                    rect: rect,
                    timeRange: timeRange,
                    midiRange: midiRange
                )

            case .twoLines:
                PianoRollRenderer.drawReferenceLine(
                    context: &context,
                    frames: referenceFrames,
                    hopDuration: hopDuration,
                    rect: rect,
                    timeRange: timeRange,
                    midiRange: midiRange,
                    transposeOffset: offset
                )
                PianoRollRenderer.drawDetectedLine(
                    context: &context,
                    points: detectedPoints,
                    rect: rect,
                    timeRange: timeRange,
                    midiRange: midiRange
                )

            case .zonesGlow:
                PianoRollRenderer.drawReferenceZones(
                    context: &context,
                    frames: referenceFrames,
                    hopDuration: hopDuration,
                    rect: rect,
                    timeRange: timeRange,
                    midiRange: midiRange,
                    transposeOffset: offset,
                    zones: zones
                )
                PianoRollRenderer.drawReferenceLine(
                    context: &context,
                    frames: referenceFrames,
                    hopDuration: hopDuration,
                    rect: rect,
                    timeRange: timeRange,
                    midiRange: midiRange,
                    transposeOffset: offset
                )
                PianoRollRenderer.drawDetectedGlow(
                    context: &context,
                    points: detectedPoints,
                    rect: rect,
                    timeRange: timeRange,
                    midiRange: midiRange
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.intonavioBackground)
    }

    /// Draw a dimmed vertical line showing the actual playback position
    /// when the user is browsing away from it.
    private func drawPlaybackIndicator(
        context: inout GraphicsContext,
        rect: CGRect,
        playbackTime: Double
    ) {
        let timeSpan = timeRange.upperBound - timeRange.lowerBound
        guard timeSpan > 0 else { return }

        let normalizedX = (playbackTime - timeRange.lowerBound) / timeSpan
        guard normalizedX >= 0, normalizedX <= 1 else { return }

        let x = CGFloat(normalizedX) * rect.width
        var line = Path()
        line.move(to: CGPoint(x: x, y: 0))
        line.addLine(to: CGPoint(x: x, y: rect.height))
        context.stroke(
            line,
            with: .color(Color.intonavioIce.opacity(0.25)),
            style: StrokeStyle(lineWidth: 1, dash: [4, 4])
        )
    }
}
