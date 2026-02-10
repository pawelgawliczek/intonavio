import SwiftUI

struct LoopControlsView: View {
    @Bindable var viewModel: PlayerViewModel

    var body: some View {
        VStack(spacing: 12) {
            loopButtons
            markerDisplay
            loopStats
        }
    }
}

// MARK: - Subviews

private extension LoopControlsView {
    var loopButtons: some View {
        HStack(spacing: 16) {
            Button("Set A") {
                viewModel.setMarkerA()
            }
            .disabled(!canSetA)

            Button("Set B") {
                viewModel.setMarkerB()
            }
            .disabled(!canSetB)

            Button("Clear Loop") {
                viewModel.clearLoop()
            }
            .disabled(!hasLoop)
        }
        .buttonStyle(.bordered)
    }

    var markerDisplay: some View {
        HStack(spacing: 24) {
            VStack {
                Text("A").font(.caption.bold())
                Text(formatTime(viewModel.markerA))
                    .font(.caption.monospacedDigit())
            }

            VStack {
                Text("B").font(.caption.bold())
                Text(formatTime(viewModel.markerB))
                    .font(.caption.monospacedDigit())
            }

            VStack {
                Text("Loop").font(.caption.bold())
                Text(viewModel.loopState.rawValue)
                    .font(.caption.monospacedDigit())
            }

            VStack {
                Text("Loops").font(.caption.bold())
                Text("\(viewModel.loopCount)")
                    .font(.caption.monospacedDigit())
            }
        }
        .foregroundStyle(.secondary)
    }

    var loopStats: some View {
        VStack(spacing: 4) {
            let stats = viewModel.seekLogger.stats
            if stats.count > 0 {
                Text("Seek Precision")
                    .font(.caption.bold())
                HStack(spacing: 12) {
                    statItem(
                        "Avg",
                        String(format: "%.0fms", stats.avgPrecisionMs)
                    )
                    statItem(
                        "Max",
                        String(format: "%.0fms", stats.maxPrecisionMs)
                    )
                    statItem(
                        "<100ms",
                        String(format: "%.0f%%", stats.percentWithin100ms)
                    )
                    statItem(
                        "Latency",
                        String(format: "%.0fms", stats.avgLatencyMs)
                    )
                }
            }
        }
        .font(.caption.monospacedDigit())
    }

    func statItem(_ label: String, _ value: String) -> some View {
        VStack {
            Text(label).foregroundStyle(.secondary)
            Text(value)
        }
    }
}

// MARK: - Helpers

private extension LoopControlsView {
    var canSetA: Bool {
        [.playing, .looping].contains(viewModel.loopState)
    }

    var canSetB: Bool {
        viewModel.markerA != nil
            && viewModel.loopState == .settingA
    }

    var hasLoop: Bool {
        viewModel.markerA != nil
    }

    func formatTime(_ time: Double?) -> String {
        guard let t = time else { return "--:--" }
        let mins = Int(t) / 60
        let secs = Int(t) % 60
        let ms = Int((t - Double(Int(t))) * 10)
        return String(format: "%d:%02d.%d", mins, secs, ms)
    }
}

#Preview {
    LoopControlsView(viewModel: PlayerViewModel())
}
