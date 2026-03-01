import SwiftUI

/// Static drawing helpers for the piano roll canvas.
enum PianoRollRenderer {
    /// Draw 3-color accuracy zone bands per voiced reference frame.
    /// Outer-to-inner: orange (±30¢), yellow (±20¢), green (±10¢).
    static func drawReferenceZones(
        context: inout GraphicsContext,
        frames: ArraySlice<ReferencePitchFrame>,
        hopDuration: Double,
        rect: CGRect,
        timeRange: ClosedRange<Double>,
        midiRange: ClosedRange<Float>,
        transposeOffset: Float = 0,
        zones: [(halfCents: Float, color: Color)]
    ) {
        let timeSpan = timeRange.upperBound - timeRange.lowerBound
        let midiSpan = midiRange.upperBound - midiRange.lowerBound
        guard timeSpan > 0, midiSpan > 0 else { return }

        for (halfCents, color) in zones {
            for frame in frames where frame.isVoiced && frame.isAudible {
                guard let midiNote = frame.midiNote else { continue }
                let midi = Float(midiNote) + transposeOffset
                guard midi >= midiRange.lowerBound, midi <= midiRange.upperBound else { continue }

                drawZoneBand(
                    context: &context, midi: midi, time: frame.time,
                    hopDuration: hopDuration, rect: rect,
                    timeLower: timeRange.lowerBound, timeSpan: timeSpan,
                    midiLower: midiRange.lowerBound, midiSpan: midiSpan,
                    halfWidthCents: halfCents, color: color
                )
            }
        }
    }

    /// Draw reference pitch as a thin dashed line only where zones exist.
    static func drawReferenceLine(
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

        let gapThreshold = hopDuration * 2
        var path = Path()
        var lastTime: Double?

        for frame in frames {
            guard frame.isVoiced, frame.isAudible, let midiNote = frame.midiNote else {
                lastTime = nil
                continue
            }
            guard frame.time >= timeRange.lowerBound, frame.time <= timeRange.upperBound else { continue }

            let midi = Float(midiNote) + transposeOffset
            let x = CGFloat((frame.time - timeRange.lowerBound) / timeSpan) * rect.width
            let y = rect.height - CGFloat((midi - midiRange.lowerBound) / midiSpan) * rect.height
            let point = CGPoint(x: x, y: y)

            if let prev = lastTime, frame.time - prev <= gapThreshold {
                path.addLine(to: point)
            } else {
                path.move(to: point)
            }
            lastTime = frame.time
        }

        context.stroke(
            path,
            with: .color(.white.opacity(0.4)),
            style: StrokeStyle(lineWidth: 1, dash: [3, 3])
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
        midiRange: ClosedRange<Float>,
        isBrowsing: Bool = false
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

        // Draw playhead "Gate" (center vertical line) — Ice accent
        var playhead = Path()
        let centerX = rect.width / 2
        playhead.move(to: CGPoint(x: centerX, y: 0))
        playhead.addLine(to: CGPoint(x: centerX, y: rect.height))

        let iceColor = Color(hex: 0xE6F6FF)
        if isBrowsing {
            context.stroke(
                playhead,
                with: .color(iceColor.opacity(0.8)),
                style: StrokeStyle(lineWidth: 2.0, lineCap: .round, dash: [6, 4])
            )
        } else {
            context.stroke(
                playhead,
                with: .color(iceColor.opacity(0.6)),
                style: StrokeStyle(lineWidth: 2.0, lineCap: .round)
            )
        }
    }
}

// MARK: - Private Helpers

private extension PianoRollRenderer {
    static func drawZoneBand(
        context: inout GraphicsContext,
        midi: Float, time: Double, hopDuration: Double,
        rect: CGRect,
        timeLower: Double, timeSpan: Double,
        midiLower: Float, midiSpan: Float,
        halfWidthCents: Float, color: Color
    ) {
        let halfSemitones = halfWidthCents / 100.0
        let bandHeight = CGFloat(2 * halfSemitones / midiSpan) * rect.height

        let x = CGFloat((time - timeLower) / timeSpan) * rect.width
        let width = CGFloat(hopDuration / timeSpan) * rect.width
        let centerY = rect.height - CGFloat((midi - midiLower) / midiSpan) * rect.height

        let bandRect = CGRect(
            x: x,
            y: centerY - bandHeight / 2,
            width: max(width, 1),
            height: bandHeight
        )
        context.fill(Path(bandRect), with: .color(color))
    }
}
