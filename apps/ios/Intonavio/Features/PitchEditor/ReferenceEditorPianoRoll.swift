import SwiftUI

/// Canvas-based editor roll: draws preview frames, playback cursor, range
/// highlight, and the in-progress draw stroke. Owns the gesture that either
/// scrubs playback (Range mode) or captures a stroke (Draw mode).
///
/// This deliberately does NOT reuse `PianoRollView` — it needs tight control
/// over the screen ↔ (time, midi) math for drawing.
struct ReferenceEditorPianoRoll: View {
    @Bindable var viewModel: ReferenceEditorViewModel

    static let windowSeconds: Double = 4.0

    private var centerTime: Double {
        if viewModel.isPlaying { return viewModel.playbackTime }
        if let start = viewModel.rangeStart, let end = viewModel.rangeEnd {
            return (start + end) / 2
        }
        return viewModel.rangeStart ?? viewModel.playbackTime
    }

    private var midiRange: (min: Double, max: Double) {
        let voiced = viewModel.previewFrames.compactMap { f -> Double? in
            guard f.isVoiced, f.isAudible, let m = f.midiNote else { return nil }
            return m
        }
        guard let lo = voiced.min(), let hi = voiced.max() else { return (48, 72) }
        return (lo - 3, hi + 3)
    }

    var body: some View {
        GeometryReader { geo in
            let geometry = EditorRollGeometry(
                size: geo.size,
                centerTime: centerTime,
                windowSpan: Self.windowSeconds * 2,
                midiMin: midiRange.min,
                midiMax: midiRange.max
            )
            ZStack {
                Color.intonavioBackground
                Canvas { ctx, _ in
                    drawGrid(ctx, geometry: geometry)
                    drawFrames(ctx, geometry: geometry)
                    drawRange(ctx, geometry: geometry)
                    drawCursor(ctx, geometry: geometry)
                    drawStroke(ctx, geometry: geometry)
                }
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(geometry: geometry))
        }
    }

    // MARK: - Gesture

    private func dragGesture(geometry: EditorRollGeometry) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let time = geometry.time(atX: value.location.x)
                switch viewModel.gesture {
                case .range:
                    viewModel.seek(to: time)
                case .draw:
                    let midi = geometry.midi(atY: value.location.y)
                    viewModel.liveStroke.append((time: time, midi: midi))
                }
            }
            .onEnded { _ in
                if viewModel.gesture == .draw { viewModel.commitStroke() }
            }
    }

    // MARK: - Drawing

    private func drawGrid(_ ctx: GraphicsContext, geometry g: EditorRollGeometry) {
        let lo = Int(g.midiMin.rounded(.down))
        let hi = Int(g.midiMax.rounded(.up))
        for midi in lo...hi {
            let y = g.y(forMidi: Double(midi))
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: g.size.width, y: y))
            let alpha = (midi % 12 == 0) ? 0.18 : 0.06
            ctx.stroke(path, with: .color(.white.opacity(alpha)), lineWidth: 0.5)
        }
    }

    private func drawFrames(_ ctx: GraphicsContext, geometry g: EditorRollGeometry) {
        let frames = viewModel.previewFrames
        guard !frames.isEmpty else { return }
        let hop = viewModel.hopDuration
        guard hop > 0 else { return }
        let startIdx = max(0, Int((g.windowStart / hop).rounded(.down)))
        let endIdx = min(frames.count - 1, Int((g.windowEnd / hop).rounded(.up)))
        guard startIdx <= endIdx else { return }
        var path = Path()
        var started = false
        for i in startIdx...endIdx {
            let f = frames[i]
            guard f.isVoiced, f.isAudible, let midi = f.midiNote else {
                started = false
                continue
            }
            let p = CGPoint(x: g.x(forTime: f.time), y: g.y(forMidi: midi))
            if started { path.addLine(to: p) } else { path.move(to: p); started = true }
        }
        ctx.stroke(path, with: .color(.intonavioAmber), lineWidth: 2)
    }

    private func drawRange(_ ctx: GraphicsContext, geometry g: EditorRollGeometry) {
        guard let s = viewModel.rangeStart, let e = viewModel.rangeEnd, e > s else { return }
        let x0 = g.x(forTime: s)
        let x1 = g.x(forTime: e)
        let rect = CGRect(x: x0, y: 0, width: max(1, x1 - x0), height: g.size.height)
        ctx.fill(Path(rect), with: .color(.intonavioAmber.opacity(0.18)))
        ctx.stroke(Path(rect), with: .color(.intonavioAmber.opacity(0.6)), lineWidth: 1)
    }

    private func drawCursor(_ ctx: GraphicsContext, geometry g: EditorRollGeometry) {
        let x = g.x(forTime: viewModel.playbackTime)
        guard x >= 0, x <= g.size.width else { return }
        var path = Path()
        path.move(to: CGPoint(x: x, y: 0))
        path.addLine(to: CGPoint(x: x, y: g.size.height))
        ctx.stroke(path, with: .color(.white.opacity(0.85)), lineWidth: 1)
    }

    private func drawStroke(_ ctx: GraphicsContext, geometry g: EditorRollGeometry) {
        let stroke = viewModel.liveStroke
        guard stroke.count >= 2 else { return }
        var path = Path()
        for (i, pt) in stroke.enumerated() {
            let p = CGPoint(x: g.x(forTime: pt.time), y: g.y(forMidi: pt.midi))
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        ctx.stroke(path, with: .color(.cyan), lineWidth: 2.5)
    }
}

/// Screen ↔ (time, midi) transforms for the editor roll.
struct EditorRollGeometry {
    let size: CGSize
    let windowStart: Double
    let windowEnd: Double
    let midiMin: Double
    let midiMax: Double

    init(size: CGSize, centerTime: Double, windowSpan: Double, midiMin: Double, midiMax: Double) {
        self.size = size
        let half = windowSpan / 2
        self.windowStart = centerTime - half
        self.windowEnd = centerTime + half
        self.midiMin = midiMin
        self.midiMax = midiMax
    }

    func x(forTime t: Double) -> CGFloat {
        let span = windowEnd - windowStart
        guard span > 0 else { return 0 }
        return CGFloat((t - windowStart) / span) * size.width
    }

    func time(atX x: CGFloat) -> Double {
        let span = windowEnd - windowStart
        return windowStart + Double(x / max(size.width, 1)) * span
    }

    func y(forMidi m: Double) -> CGFloat {
        let span = midiMax - midiMin
        guard span > 0 else { return size.height / 2 }
        let t = (m - midiMin) / span
        return CGFloat(1 - t) * size.height
    }

    func midi(atY y: CGFloat) -> Double {
        let span = midiMax - midiMin
        let t = 1 - Double(y / max(size.height, 1))
        return midiMin + t * span
    }
}
