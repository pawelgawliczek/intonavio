import SwiftUI

struct ContentView: View {
    @State private var viewModel = PitchViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Pitch Detection Spike")
                    .font(.title2.bold())

                modePicker
                pitchDisplay
                pitchGraph

                if viewModel.inputMode == .simulator {
                    toneSlider
                }

                centsIndicator
                controlButton
                latencyStats

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
            }
            .padding()
        }
    }
}

// MARK: - Subviews

private extension ContentView {
    var modePicker: some View {
        Picker("Input", selection: $viewModel.inputMode) {
            ForEach(InputMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .disabled(viewModel.isRunning)
    }

    var pitchDisplay: some View {
        VStack(spacing: 6) {
            Text(viewModel.noteName)
                .font(.system(
                    size: 56,
                    weight: .bold,
                    design: .rounded
                ))
                .foregroundStyle(noteColor)

            Text(frequencyText)
                .font(.title3.monospacedDigit())

            Text(confidenceText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    var pitchGraph: some View {
        PitchGraphView(
            points: viewModel.pitchHistory,
            timeWindow: viewModel.graphTimeWindow,
            currentFrequency: viewModel.frequency
        )
        .frame(height: 320)
    }

    var toneSlider: some View {
        VStack(spacing: 4) {
            Text(String(
                format: "Test Tone: %.0f Hz (%@)",
                viewModel.testToneHz,
                toneNoteName
            ))
            .font(.caption.monospacedDigit())

            Slider(
                value: $viewModel.testToneHz,
                in: 100...800,
                step: 1
            )
            .onChange(of: viewModel.testToneHz) {
                viewModel.updateTestTone()
            }
        }
    }

    var centsIndicator: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                let midX = geo.size.width / 2
                let offset = CGFloat(viewModel.centsDeviation)
                    / 50.0 * midX

                ZStack {
                    Rectangle()
                        .fill(.secondary.opacity(0.3))
                        .frame(width: 1)
                        .position(
                            x: midX,
                            y: geo.size.height / 2
                        )

                    Circle()
                        .fill(noteColor)
                        .frame(width: 16, height: 16)
                        .position(
                            x: midX + offset,
                            y: geo.size.height / 2
                        )
                }
            }
            .frame(height: 24)

            Text(centsText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    var controlButton: some View {
        Button(action: viewModel.toggleDetection) {
            Text(viewModel.isRunning ? "Stop" : "Start")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(viewModel.isRunning ? .red : .blue)
    }

    var latencyStats: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Latency (processing only)")
                .font(.caption.bold())
            HStack(spacing: 16) {
                statLabel("Min", viewModel.latencyMin)
                statLabel("Avg", viewModel.latencyAvg)
                statLabel("P95", viewModel.latencyP95)
                statLabel("Max", viewModel.latencyMax)
            }
            Text("Samples: \(viewModel.sampleCount)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .font(.caption.monospacedDigit())
    }

    func statLabel(
        _ label: String,
        _ value: Double
    ) -> some View {
        VStack {
            Text(label)
                .foregroundStyle(.secondary)
            Text(String(format: "%.1fms", value))
        }
    }
}

// MARK: - Computed Properties

private extension ContentView {
    var frequencyText: String {
        viewModel.frequency > 0
            ? String(format: "%.1f Hz", viewModel.frequency)
            : "-- Hz"
    }

    var confidenceText: String {
        viewModel.confidence > 0
            ? String(
                format: "Confidence: %.0f%%",
                viewModel.confidence * 100
            )
            : "Confidence: --"
    }

    var centsText: String {
        guard viewModel.frequency > 0 else { return "-- cents" }
        let sign = viewModel.centsDeviation >= 0 ? "+" : ""
        return String(
            format: "%@%.0f cents",
            sign,
            viewModel.centsDeviation
        )
    }

    var toneNoteName: String {
        let info = NoteMapper.noteInfo(
            forFrequency: viewModel.testToneHz
        )
        return info.fullName
    }

    var noteColor: Color {
        let cents = abs(viewModel.centsDeviation)
        if viewModel.frequency == 0 { return .secondary }
        if cents <= 10 { return .green }
        if cents <= 25 { return .yellow }
        if cents <= 50 { return .orange }
        return .red
    }
}

#Preview {
    ContentView()
}
