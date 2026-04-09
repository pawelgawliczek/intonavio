import SwiftUI

/// Canvas-based editor roll: draws preview frames, playback cursor, range
/// highlight, and the in-progress draw stroke.
///
/// All touch gestures (tap, 1-finger drag, 2-finger pan) are handled by a
/// single UIKit overlay (`EditorGestureView`) to avoid SwiftUI/UIKit conflicts.
struct ReferenceEditorPianoRoll: View {
    @Bindable var viewModel: ReferenceEditorViewModel

    private var centerTime: Double {
        if viewModel.isPlaying { return viewModel.playbackTime }
        return viewModel.scrollCenter
    }

    private var midiRange: (min: Double, max: Double) {
        var allFrames: [[ReferencePitchFrame]] = [viewModel.previewFrames]
        if viewModel.showBaseLayer { allFrames.append(viewModel.baseFrames) }
        if viewModel.showOtherVariantLayer {
            allFrames.append(contentsOf: viewModel.otherVariantFrames.values)
        }
        let voiced = allFrames.flatMap { $0 }.compactMap { f -> Double? in
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
                windowSpan: viewModel.visibleWindowSpan,
                midiMin: midiRange.min,
                midiMax: midiRange.max
            )
            ZStack {
                Color.intonavioBackground
                Canvas { ctx, _ in
                    drawGrid(ctx, geometry: geometry)
                    drawTimeMarkers(ctx, geometry: geometry)
                    // Edited (amber) first — behind so other layers show on top
                    drawFramePath(ctx, geometry: geometry,
                                  frames: viewModel.previewFrames,
                                  color: .intonavioAmber, lineWidth: 2.5)
                    // Base layer on top of edited (only when edits exist, otherwise identical)
                    if viewModel.showBaseLayer, viewModel.isDirty {
                        let baseColor = viewModel.baseSource?.editorColor ?? .blue
                        drawFramePath(ctx, geometry: geometry,
                                      frames: viewModel.baseFrames,
                                      color: baseColor, lineWidth: 1.5)
                    }
                    // Other variants on top
                    if viewModel.showOtherVariantLayer {
                        for (source, frames) in viewModel.otherVariantFrames {
                            drawFramePath(ctx, geometry: geometry,
                                          frames: frames,
                                          color: source.editorColor, lineWidth: 1.5)
                        }
                    }
                    drawRange(ctx, geometry: geometry)
                    drawCursor(ctx, geometry: geometry)
                    drawStroke(ctx, geometry: geometry)
                }
                EditorGestureOverlay(viewModel: viewModel, geometry: geometry)
            }
            .overlay(alignment: .topTrailing) {
                ReferenceEditorLegend(viewModel: viewModel)
                    .padding(8)
            }
            .overlay(alignment: .trailing) {
                zoomButtons.padding(8)
            }
        }
    }

    private var zoomButtons: some View {
        VStack(spacing: 8) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    viewModel.setZoom(viewModel.zoomLevel * 1.5)
                }
            } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    viewModel.setZoom(viewModel.zoomLevel / 1.5)
                }
            } label: {
                Image(systemName: "minus")
                    .font(.title3.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
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

    private func drawTimeMarkers(_ ctx: GraphicsContext, geometry g: EditorRollGeometry) {
        let span = g.windowEnd - g.windowStart
        // Pick interval: 1s, 2s, 5s, 10s, 15s, 30s, 60s based on visible span
        let intervals: [Double] = [1, 2, 5, 10, 15, 30, 60]
        let targetCount = Double(g.size.width) / 80 // ~80pt between labels
        let ideal = span / max(targetCount, 1)
        let interval = intervals.first { $0 >= ideal } ?? 60

        let firstTick = (max(0, g.windowStart) / interval).rounded(.up) * interval
        var t = firstTick
        while t <= min(g.windowEnd, viewModel.songDuration) {
            let x = g.x(forTime: t)

            // Vertical tick line
            var tick = Path()
            tick.move(to: CGPoint(x: x, y: 0))
            tick.addLine(to: CGPoint(x: x, y: g.size.height))
            ctx.stroke(tick, with: .color(.white.opacity(0.12)), lineWidth: 0.5)

            // Time label at top
            let total = Int(t)
            let label = String(format: "%d:%02d", total / 60, total % 60)
            let text = ctx.resolve(
                Text(label)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
            )
            ctx.draw(text, at: CGPoint(x: x, y: 8), anchor: .top)

            t += interval
        }
    }

    private func drawFramePath(
        _ ctx: GraphicsContext,
        geometry g: EditorRollGeometry,
        frames: [ReferencePitchFrame],
        color: Color,
        lineWidth: CGFloat
    ) {
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
        ctx.stroke(path, with: .color(color), lineWidth: lineWidth)
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

// MARK: - All-UIKit Gesture Overlay

/// Full-frame transparent UIView that handles all canvas gestures via UIKit:
/// - Tap (1 finger) → seek
/// - Drag (1 finger) → select range or draw stroke
/// - Drag (2 fingers) → scroll/pan
struct EditorGestureOverlay: UIViewRepresentable {
    let viewModel: ReferenceEditorViewModel
    let geometry: EditorRollGeometry

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = true

        // Tap → seek
        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )

        // 1-finger drag → select / draw
        let oneFinger = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleOneFingerPan(_:))
        )
        oneFinger.minimumNumberOfTouches = 1
        oneFinger.maximumNumberOfTouches = 1

        // 2-finger drag → scroll
        let twoFinger = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTwoFingerPan(_:))
        )
        twoFinger.minimumNumberOfTouches = 2
        twoFinger.maximumNumberOfTouches = 2

        // Tap requires 1-finger drag to fail (so quick taps aren't swallowed)
        tap.require(toFail: oneFinger)

        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(oneFinger)
        view.addGestureRecognizer(twoFinger)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.viewModel = viewModel
        context.coordinator.geometry = geometry
    }

    func makeCoordinator() -> Coordinator { Coordinator(viewModel: viewModel, geometry: geometry) }

    @MainActor final class Coordinator: NSObject {
        var viewModel: ReferenceEditorViewModel
        var geometry: EditorRollGeometry
        private var dragStartTime: Double?
        private var scrollAnchorCenter: Double = 0

        init(viewModel: ReferenceEditorViewModel, geometry: EditorRollGeometry) {
            self.viewModel = viewModel
            self.geometry = geometry
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let x = gesture.location(in: gesture.view).x
            let time = geometry.time(atX: x)
            viewModel.seek(to: time)
        }

        @objc func handleOneFingerPan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view else { return }
            let location = gesture.location(in: view)

            switch gesture.state {
            case .began:
                dragStartTime = geometry.time(atX: location.x)

            case .changed:
                let time = geometry.time(atX: location.x)
                switch viewModel.gesture {
                case .range:
                    guard let anchor = dragStartTime else { return }
                    viewModel.rangeStart = max(0, min(anchor, time))
                    viewModel.rangeEnd = min(viewModel.songDuration, max(anchor, time))
                case .draw:
                    let midi = geometry.midi(atY: location.y)
                    viewModel.liveStroke.append((time: time, midi: midi))
                }

            case .ended, .cancelled:
                dragStartTime = nil
                if viewModel.gesture == .draw { viewModel.commitStroke() }

            default:
                break
            }
        }

        @objc func handleTwoFingerPan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view, view.bounds.width > 0 else { return }

            switch gesture.state {
            case .began:
                scrollAnchorCenter = viewModel.scrollCenter

            case .changed:
                let tx = gesture.translation(in: view).x
                let span = viewModel.visibleWindowSpan
                let delta = -(Double(tx) / Double(view.bounds.width)) * span
                viewModel.setScrollCenter(scrollAnchorCenter + delta)

            default:
                break
            }
        }
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
