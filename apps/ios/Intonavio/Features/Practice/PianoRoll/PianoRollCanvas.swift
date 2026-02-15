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
                midiRange: midiRange
            )

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
        .background(Color.platformBackground)
    }
}
