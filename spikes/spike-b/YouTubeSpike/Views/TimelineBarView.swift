import SwiftUI

struct TimelineBarView: View {
    @Bindable var viewModel: PlayerViewModel

    private let trackHeight: CGFloat = 8
    private let markerHitArea: CGFloat = 44
    private let markerWidth: CGFloat = 3

    @GestureState private var isDraggingA = false
    @GestureState private var isDraggingB = false

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    trackBackground
                    progressFill(width: width)
                    loopRegion(width: width)
                    markerView(
                        time: viewModel.markerA,
                        color: .green,
                        label: "A",
                        width: width,
                        isDragging: isDraggingA,
                        gestureState: $isDraggingA,
                        onDrag: { viewModel.setMarkerAPosition($0) }
                    )
                    markerView(
                        time: viewModel.markerB,
                        color: .red,
                        label: "B",
                        width: width,
                        isDragging: isDraggingB,
                        gestureState: $isDraggingB,
                        onDrag: { viewModel.setMarkerBPosition($0) }
                    )
                    playhead(width: width)
                }
                .frame(height: markerHitArea)
                .contentShape(Rectangle())
                .gesture(tapSeekGesture(width: width))
            }
            .frame(height: markerHitArea)

            timeLabels
        }
    }
}

// MARK: - Track Components

private extension TimelineBarView {
    var trackBackground: some View {
        RoundedRectangle(cornerRadius: trackHeight / 2)
            .fill(Color.gray.opacity(0.3))
            .frame(height: trackHeight)
            .frame(maxWidth: .infinity)
            .padding(.vertical, (markerHitArea - trackHeight) / 2)
    }

    func progressFill(width: CGFloat) -> some View {
        let fillWidth = timeToX(viewModel.currentTime, width)
        return RoundedRectangle(cornerRadius: trackHeight / 2)
            .fill(Color.accentColor)
            .frame(width: max(0, fillWidth), height: trackHeight)
            .padding(.vertical, (markerHitArea - trackHeight) / 2)
    }

    func loopRegion(width: CGFloat) -> some View {
        Group {
            if let a = viewModel.markerA, let b = viewModel.markerB {
                let xA = timeToX(a, width)
                let xB = timeToX(b, width)
                Rectangle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: max(0, xB - xA), height: trackHeight)
                    .offset(x: xA)
                    .padding(.vertical, (markerHitArea - trackHeight) / 2)
            }
        }
    }

    func playhead(width: CGFloat) -> some View {
        Circle()
            .fill(Color.accentColor)
            .frame(width: 12, height: 12)
            .offset(x: timeToX(viewModel.currentTime, width) - 6)
    }
}

// MARK: - Markers

private extension TimelineBarView {
    func markerView(
        time: Double?,
        color: Color,
        label: String,
        width: CGFloat,
        isDragging: Bool,
        gestureState: GestureState<Bool>,
        onDrag: @escaping (Double) -> Void
    ) -> some View {
        Group {
            if let t = time {
                let x = timeToX(t, width)
                ZStack {
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
                .offset(x: x - markerHitArea / 2)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .updating(gestureState) { _, state, _ in
                            state = true
                        }
                        .onChanged { value in
                            let newTime = xToTime(value.location.x + x - markerHitArea / 2, width)
                            onDrag(newTime)
                        }
                )
                .zIndex(isDragging ? 2 : 1)
            }
        }
    }
}

// MARK: - Gestures

private extension TimelineBarView {
    func tapSeekGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let time = xToTime(value.location.x, width)
                viewModel.seek(to: time)
            }
    }
}

// MARK: - Time Labels

private extension TimelineBarView {
    var timeLabels: some View {
        HStack {
            Text(formatTime(viewModel.currentTime))
            Spacer()
            Text(formatTime(viewModel.duration))
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
    }

    func formatTime(_ time: Double) -> String {
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Coordinate Mapping

private extension TimelineBarView {
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
    TimelineBarView(viewModel: PlayerViewModel())
        .padding()
}
