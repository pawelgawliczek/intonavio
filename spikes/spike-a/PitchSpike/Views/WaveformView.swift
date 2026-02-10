import SwiftUI

/// Scrolling pitch graph that plots detected frequency over time.
/// Dark background, note names on Y-axis, time on X-axis.
struct PitchGraphView: View {
    let points: [PitchPoint]
    let timeWindow: TimeInterval
    let currentFrequency: Float

    // MIDI range: E2 (MIDI 40, ~82Hz) to C6 (MIDI 84, ~1047Hz)
    private let minMidi: Float = 40  // E2
    private let maxMidi: Float = 84  // C6
    private let lineWidth: CGFloat = 2.0
    /// Max time gap (seconds) before breaking the line
    /// (avoids connecting across silence gaps).
    private let maxGap: TimeInterval = 0.15

    /// Notes to label on Y-axis — one per octave boundary
    /// plus musically useful reference points.
    private let gridNotes: [(midi: Int, name: String)] = [
        (40, "E2"), (43, "G2"), (45, "A2"),
        (48, "C3"), (52, "E3"), (55, "G3"),
        (57, "A3"), (60, "C4"), (64, "E4"),
        (67, "G4"), (69, "A4"), (72, "C5"),
        (76, "E5"), (79, "G5"), (81, "A5"),
        (84, "C6"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            yAxisLabels
                .frame(width: 32)

            VStack(spacing: 0) {
                Canvas { context, size in
                    drawBackground(context: context, size: size)
                    drawNoteGrid(context: context, size: size)
                    drawTimeGrid(context: context, size: size)
                    drawPitchLine(context: context, size: size)
                }

                xAxisLabels
                    .frame(height: 16)
            }
        }
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Drawing

private extension PitchGraphView {
    var latestTime: TimeInterval {
        points.last?.time ?? 0
    }

    var visibleStart: TimeInterval {
        max(0, latestTime - timeWindow)
    }

    func midiToY(_ midi: Float, height: CGFloat) -> CGFloat {
        let clamped = min(max(midi, minMidi), maxMidi)
        let ratio = (clamped - minMidi) / (maxMidi - minMidi)
        return height * (1.0 - CGFloat(ratio))
    }

    func hzToMidi(_ hz: Float) -> Float {
        69.0 + 12.0 * log2(hz / 440.0)
    }

    func timeToX(_ t: TimeInterval, width: CGFloat) -> CGFloat {
        let ratio = (t - visibleStart) / timeWindow
        return CGFloat(ratio) * width
    }

    func drawBackground(
        context: GraphicsContext,
        size: CGSize
    ) {
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(Color(white: 0.08))
        )
    }

    func drawNoteGrid(
        context: GraphicsContext,
        size: CGSize
    ) {
        for note in gridNotes {
            let y = midiToY(Float(note.midi), height: size.height)

            // Brighter lines on C notes (octave boundaries)
            let isC = note.name.hasPrefix("C")
            let opacity = isC ? 0.2 : 0.08
            let lineWidth: CGFloat = isC ? 0.75 : 0.5

            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(
                path,
                with: .color(.white.opacity(opacity)),
                lineWidth: lineWidth
            )
        }
    }

    func drawTimeGrid(
        context: GraphicsContext,
        size: CGSize
    ) {
        let startSec = Int(visibleStart)
        let endSec = Int(visibleStart + timeWindow) + 1
        let step = timeWindow > 15 ? 5 : 2

        var sec = startSec - (startSec % step) + step
        while sec <= endSec {
            let x = timeToX(TimeInterval(sec), width: size.width)
            guard x > 0, x < size.width else {
                sec += step
                continue
            }
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(
                path,
                with: .color(.white.opacity(0.1)),
                lineWidth: 0.5
            )
            sec += step
        }
    }

    func drawPitchLine(
        context: GraphicsContext,
        size: CGSize
    ) {
        guard points.count >= 2 else { return }

        // Build segments — break the line when there's
        // a gap in time (silence / unvoiced).
        var segments: [[CGPoint]] = []
        var current: [CGPoint] = []

        var prevTime: TimeInterval = -1

        for point in points {
            let x = timeToX(point.time, width: size.width)
            guard x >= -10, x <= size.width + 10 else {
                continue
            }
            let midi = hzToMidi(point.frequency)
            let y = midiToY(midi, height: size.height)
            let pt = CGPoint(x: x, y: y)

            if prevTime >= 0, (point.time - prevTime) > maxGap {
                if current.count >= 2 {
                    segments.append(current)
                }
                current = [pt]
            } else {
                current.append(pt)
            }
            prevTime = point.time
        }
        if current.count >= 2 {
            segments.append(current)
        }

        // Draw each segment as a smooth line
        let color = Color(red: 0.3, green: 0.7, blue: 1.0)

        for segment in segments {
            var path = Path()
            path.move(to: segment[0])
            for i in 1..<segment.count {
                path.addLine(to: segment[i])
            }

            // Glow: wider, semi-transparent stroke behind
            context.stroke(
                path,
                with: .color(color.opacity(0.3)),
                style: StrokeStyle(
                    lineWidth: lineWidth * 3,
                    lineCap: .round,
                    lineJoin: .round
                )
            )

            // Main line
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
    }
}

// MARK: - Axis Labels

private extension PitchGraphView {
    var yAxisLabels: some View {
        GeometryReader { geo in
            let height = geo.size.height
            ForEach(gridNotes, id: \.midi) { note in
                let y = midiToY(
                    Float(note.midi), height: height
                )
                Text(note.name)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(
                        note.name.hasPrefix("C")
                            ? .white.opacity(0.7)
                            : .white.opacity(0.4)
                    )
                    .position(x: 16, y: y)
            }
        }
    }

    var xAxisLabels: some View {
        GeometryReader { geo in
            let startSec = Int(visibleStart)
            let endSec = Int(visibleStart + timeWindow) + 1
            let step = timeWindow > 15 ? 5 : 2

            ForEach(
                timeLabels(
                    start: startSec,
                    end: endSec,
                    step: step,
                    width: geo.size.width
                ),
                id: \.sec
            ) { label in
                Text(formatTime(label.sec))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .position(x: label.x, y: 8)
            }
        }
    }

    struct TimeLabel {
        let sec: Int
        let x: CGFloat
    }

    func timeLabels(
        start: Int,
        end: Int,
        step: Int,
        width: CGFloat
    ) -> [TimeLabel] {
        var labels: [TimeLabel] = []
        var sec = start - (start % step) + step
        while sec <= end {
            let x = timeToX(TimeInterval(sec), width: width)
            if x > 10, x < width - 10 {
                labels.append(TimeLabel(sec: sec, x: x))
            }
            sec += step
        }
        return labels
    }

    func formatTime(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

#Preview {
    let mockPoints: [PitchPoint] = (0..<400).map { i in
        let t = Double(i) * 0.05
        // Simulate singing around C4-E4 range
        let midi = 60.0 + 4.0 * sin(t * 0.5) + 2.0 * sin(t * 2)
        let hz = Float(440.0 * pow(2.0, (midi - 69.0) / 12.0))
        return PitchPoint(time: t, frequency: hz, confidence: 0.92)
    }
    PitchGraphView(
        points: mockPoints,
        timeWindow: 20,
        currentFrequency: 262
    )
    .frame(height: 300)
    .padding()
    .background(.black)
}
