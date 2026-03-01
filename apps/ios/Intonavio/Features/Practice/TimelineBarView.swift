import SwiftUI

struct TimelineBarView: View {
    @Bindable var viewModel: PracticeViewModel

    private let trackHeight: CGFloat = 8
    private let markerHitArea: CGFloat = 44
    private let markerWidth: CGFloat = 3

    @State private var dragStartTimeA: Double?
    @State private var dragStartTimeB: Double?
    @GestureState private var isDraggingA = false
    @GestureState private var isDraggingB = false

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                timelineContent(width: geo.size.width)
            }
            .frame(height: markerHitArea)

            timeLabels
        }
    }

    private func timelineContent(width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            trackBackground
            progressFill(width: width)
            loopRegion(width: width)
            markerA(width: width)
            markerB(width: width)
            playhead(width: width)
        }
        .frame(height: markerHitArea)
        .contentShape(Rectangle())
        .gesture(tapSeekGesture(width: width))
    }
}

// MARK: - Track Components

private extension TimelineBarView {
    var trackBackground: some View {
        RoundedRectangle(cornerRadius: trackHeight / 2)
            .fill(Color.intonavioSurface)
            .frame(height: trackHeight)
            .frame(maxWidth: .infinity)
            .padding(.vertical, (markerHitArea - trackHeight) / 2)
    }

    func progressFill(width: CGFloat) -> some View {
        let fillWidth = timeToX(viewModel.currentTime, width)
        return RoundedRectangle(cornerRadius: trackHeight / 2)
            .fill(LinearGradient.intonavio)
            .frame(width: max(0, fillWidth), height: trackHeight)
            .padding(.vertical, (markerHitArea - trackHeight) / 2)
    }

    func loopRegion(width: CGFloat) -> some View {
        Group {
            if let a = viewModel.markerA, let b = viewModel.markerB {
                let xA = timeToX(a, width)
                let xB = timeToX(b, width)
                Rectangle()
                    .fill(LinearGradient.intonavio.opacity(0.15))
                    .frame(width: max(0, xB - xA), height: trackHeight)
                    .offset(x: xA)
                    .padding(.vertical, (markerHitArea - trackHeight) / 2)
            }
        }
    }

    func playhead(width: CGFloat) -> some View {
        Circle()
            .fill(Color.intonavioIce)
            .frame(width: 12, height: 12)
            .offset(x: timeToX(viewModel.currentTime, width) - 6)
    }
}

// MARK: - Markers

private extension TimelineBarView {
    func markerA(width: CGFloat) -> some View {
        Group {
            if let time = viewModel.markerA {
                markerBody(time: time, color: .green, label: "A", width: width)
                    .zIndex(isDraggingA ? 2 : 1)
                    .gesture(markerDragGesture(
                        gestureState: $isDraggingA,
                        dragStartTime: $dragStartTimeA,
                        currentTime: time,
                        width: width,
                        onDrag: { viewModel.setMarkerAPosition($0) }
                    ))
            }
        }
    }

    func markerB(width: CGFloat) -> some View {
        Group {
            if let time = viewModel.markerB {
                markerBody(time: time, color: .red, label: "B", width: width)
                    .zIndex(isDraggingB ? 2 : 1)
                    .gesture(markerDragGesture(
                        gestureState: $isDraggingB,
                        dragStartTime: $dragStartTimeB,
                        currentTime: time,
                        width: width,
                        onDrag: { viewModel.setMarkerBPosition($0) }
                    ))
            }
        }
    }

    func markerBody(
        time: Double,
        color: Color,
        label: String,
        width: CGFloat
    ) -> some View {
        let xPos = timeToX(time, width)
        return ZStack {
            Rectangle()
                .fill(color)
                .frame(width: markerWidth, height: markerHitArea)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(color, in: Capsule())
                .offset(y: -(markerHitArea / 2 + 8))
        }
        .frame(width: markerHitArea, height: markerHitArea)
        .contentShape(Rectangle())
        .offset(x: xPos - markerHitArea / 2)
    }

    func markerDragGesture(
        gestureState: GestureState<Bool>,
        dragStartTime: Binding<Double?>,
        currentTime: Double,
        width: CGFloat,
        onDrag: @escaping (Double) -> Void
    ) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating(gestureState) { _, state, _ in
                state = true
            }
            .onChanged { value in
                if dragStartTime.wrappedValue == nil {
                    dragStartTime.wrappedValue = currentTime
                }
                let startTime = dragStartTime.wrappedValue ?? currentTime
                let delta = Double(value.translation.width / width) * viewModel.duration
                onDrag(startTime + delta)
            }
            .onEnded { _ in
                dragStartTime.wrappedValue = nil
            }
    }
}

// MARK: - Gestures & Helpers

private extension TimelineBarView {
    func tapSeekGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let time = xToTime(value.location.x, width)
                viewModel.seek(to: time)
            }
    }

    var timeLabels: some View {
        HStack {
            Text(formatTime(viewModel.currentTime))
            Spacer()
            Text(formatTime(viewModel.duration))
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(Color.intonavioTextSecondary)
    }

    func formatTime(_ time: Double) -> String {
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    func timeToX(_ time: Double, _ width: CGFloat) -> CGFloat {
        guard viewModel.duration > 0 else { return 0 }
        let ratio = time / viewModel.duration
        return CGFloat(ratio) * width
    }

    func xToTime(_ x: CGFloat, _ width: CGFloat) -> Double {
        guard width > 0 else { return 0 }
        let ratio = max(0, min(1, x / width))
        return Double(ratio) * viewModel.duration
    }
}

#Preview {
    TimelineBarView(viewModel: PracticeViewModel(songId: "s1", videoId: "v1"))
        .padding()
}
