import SwiftUI

/// Static drawing helpers for the piano roll canvas.
enum PianoRollRenderer {
    /// Draw semi-transparent reference pitch zones (1 semitone height).
    static func drawReferenceZones(
        context: inout GraphicsContext,
        frames: ArraySlice<ReferencePitchFrame>,
        hopDuration: Double,
        rect: CGRect,
        timeRange: ClosedRange<Double>,
        midiRange: ClosedRange<Float>,
        transposeOffset: Float = 0
    ) {
        let timeSpan = timeRange.upperBound - timeRange.lowerBound
        let midiSpan = midiRange.upperBound - midiRange.lowerBound
        guard timeSpan > 0, midiSpan > 0 else { return }

        for frame in frames where frame.isVoiced {
            guard let midiNote = frame.midiNote else { continue }
            let midi = Float(midiNote) + transposeOffset
            guard midi >= midiRange.lowerBound, midi <= midiRange.upperBound else { continue }

            let x = CGFloat((frame.time - timeRange.lowerBound) / timeSpan) * rect.width
            let width = CGFloat(hopDuration / timeSpan) * rect.width
            let noteHeight = rect.height / CGFloat(midiSpan)
            let y = rect.height - CGFloat((midi - midiRange.lowerBound) / midiSpan) * rect.height
                - noteHeight / 2

            let noteRect = CGRect(x: x, y: y, width: max(width, 1), height: noteHeight)
            context.fill(
                Path(noteRect),
                with: .color(.blue.opacity(0.15))
            )
        }
    }

    /// Draw reference pitch as a thin dashed gray line.
    static func drawReferenceLine(
        context: inout GraphicsContext,
        frames: ArraySlice<ReferencePitchFrame>,
        rect: CGRect,
        timeRange: ClosedRange<Double>,
        midiRange: ClosedRange<Float>,
        transposeOffset: Float = 0
    ) {
        let path = buildPath(
            frames: frames.compactMap { frame -> (Double, Float)? in
                guard frame.isVoiced, let midi = frame.midiNote else { return nil }
                return (frame.time, Float(midi) + transposeOffset)
            },
            rect: rect,
            timeRange: timeRange,
            midiRange: midiRange
        )

        context.stroke(
            path,
            with: .color(.gray.opacity(0.6)),
            style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
        )
    }

    /// Draw detected pitch as a solid colored line (color = accuracy).
    static func drawDetectedLine(
        context: inout GraphicsContext,
        points: [DetectedPitchPoint],
        rect: CGRect,
        timeRange: ClosedRange<Double>,
        midiRange: ClosedRange<Float>
    ) {
        let timeSpan = timeRange.upperBound - timeRange.lowerBound
        let midiSpan = midiRange.upperBound - midiRange.lowerBound
        guard timeSpan > 0, midiSpan > 0 else { return }

        let filtered = points.filter {
            $0.time >= timeRange.lowerBound && $0.time <= timeRange.upperBound
        }
        guard filtered.count >= 2 else { return }

        // Draw segments with per-point color
        for i in 1..<filtered.count {
            let prev = filtered[i - 1]
            let curr = filtered[i]

            // Skip large time gaps (>0.1s) to avoid connecting separated phrases
            guard curr.time - prev.time < 0.1 else { continue }

            let x1 = CGFloat((prev.time - timeRange.lowerBound) / timeSpan) * rect.width
            let y1 = rect.height - CGFloat((prev.midi - midiRange.lowerBound) / midiSpan) * rect.height
            let x2 = CGFloat((curr.time - timeRange.lowerBound) / timeSpan) * rect.width
            let y2 = rect.height - CGFloat((curr.midi - midiRange.lowerBound) / midiSpan) * rect.height

            var segment = Path()
            segment.move(to: CGPoint(x: x1, y: y1))
            segment.addLine(to: CGPoint(x: x2, y: y2))

            context.stroke(
                segment,
                with: .color(curr.accuracy.color),
                lineWidth: 2.5
            )
        }
    }

    /// Draw detected pitch as a glowing animated trail (intensity = accuracy).
    static func drawDetectedGlow(
        context: inout GraphicsContext,
        points: [DetectedPitchPoint],
        rect: CGRect,
        timeRange: ClosedRange<Double>,
        midiRange: ClosedRange<Float>
    ) {
        let timeSpan = timeRange.upperBound - timeRange.lowerBound
        let midiSpan = midiRange.upperBound - midiRange.lowerBound
        guard timeSpan > 0, midiSpan > 0 else { return }

        let filtered = points.filter {
            $0.time >= timeRange.lowerBound && $0.time <= timeRange.upperBound
        }

        for point in filtered {
            let x = CGFloat((point.time - timeRange.lowerBound) / timeSpan) * rect.width
            let y = rect.height - CGFloat((point.midi - midiRange.lowerBound) / midiSpan) * rect.height

            let glowRadius: CGFloat = point.accuracy == .excellent ? 8 : 5
            let opacity: Double = point.accuracy == .poor ? 0.3 : 0.7

            let circle = Path(
                ellipseIn: CGRect(
                    x: x - glowRadius / 2,
                    y: y - glowRadius / 2,
                    width: glowRadius,
                    height: glowRadius
                )
            )

            context.fill(
                circle,
                with: .color(point.accuracy.color.opacity(opacity))
            )
        }
    }

    /// Draw horizontal grid lines for semitone markers.
    static func drawGrid(
        context: inout GraphicsContext,
        rect: CGRect,
        midiRange: ClosedRange<Float>
    ) {
        let midiSpan = midiRange.upperBound - midiRange.lowerBound
        guard midiSpan > 0 else { return }

        let startMidi = Int(ceil(midiRange.lowerBound))
        let endMidi = Int(floor(midiRange.upperBound))

        for midi in startMidi...endMidi {
            let y = rect.height - CGFloat(Float(midi) - midiRange.lowerBound) / CGFloat(midiSpan) * rect.height
            var line = Path()
            line.move(to: CGPoint(x: 0, y: y))
            line.addLine(to: CGPoint(x: rect.width, y: y))

            let isC = midi % 12 == 0
            context.stroke(
                line,
                with: .color(.gray.opacity(isC ? 0.3 : 0.1)),
                lineWidth: isC ? 1.0 : 0.5
            )
        }

        // Draw playhead (center vertical line)
        var playhead = Path()
        let centerX = rect.width / 2
        playhead.move(to: CGPoint(x: centerX, y: 0))
        playhead.addLine(to: CGPoint(x: centerX, y: rect.height))
        context.stroke(
            playhead,
            with: .color(.white.opacity(0.3)),
            lineWidth: 1.0
        )
    }
}

// MARK: - Path Builder

private extension PianoRollRenderer {
    static func buildPath(
        frames: [(Double, Float)],
        rect: CGRect,
        timeRange: ClosedRange<Double>,
        midiRange: ClosedRange<Float>
    ) -> Path {
        let timeSpan = timeRange.upperBound - timeRange.lowerBound
        let midiSpan = midiRange.upperBound - midiRange.lowerBound
        guard timeSpan > 0, midiSpan > 0 else { return Path() }

        var path = Path()
        var isFirst = true

        for (time, midi) in frames {
            guard time >= timeRange.lowerBound, time <= timeRange.upperBound else { continue }

            let x = CGFloat((time - timeRange.lowerBound) / timeSpan) * rect.width
            let y = rect.height - CGFloat((midi - midiRange.lowerBound) / midiSpan) * rect.height

            if isFirst {
                path.move(to: CGPoint(x: x, y: y))
                isFirst = false
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }
}
