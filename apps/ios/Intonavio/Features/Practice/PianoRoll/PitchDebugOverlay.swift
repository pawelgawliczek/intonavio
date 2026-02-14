#if DEBUG
import SwiftUI

/// Debug overlay showing raw pitch detection stats and FPS counter.
struct PitchDebugOverlay: View {
    let pitchDetector: PitchDetector
    let scoringEngine: ScoringEngine?
    let referenceStore: ReferencePitchStore
    let currentTime: Double

    @State private var frameCount = 0
    @State private var fps: Int = 0
    @State private var lastFPSUpdate = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            fpsRow
            pitchRow
            referenceRow
            scoringRow
        }
        .font(.caption2.monospaced())
        .padding(6)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onAppear { startFPSCounter() }
    }
}

// MARK: - Rows

private extension PitchDebugOverlay {
    var fpsRow: some View {
        Text("FPS: \(fps)")
            .foregroundStyle(fps >= 43 ? .green : .red)
    }

    var pitchRow: some View {
        Group {
            if let result = pitchDetector.latestResult {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Hz: \(String(format: "%.1f", result.frequency))")
                    Text("Conf: \(String(format: "%.2f", result.confidence))")
                    Text("MIDI: \(result.midiNote) (\(result.noteName))")
                    Text("Cents: \(String(format: "%.1f", result.centsDeviation))")
                }
            } else {
                Text("No pitch detected")
                    .foregroundStyle(.secondary)
            }
        }
    }

    var referenceRow: some View {
        Group {
            if let frame = referenceStore.frame(at: currentTime) {
                let status = frame.isVoiced ? "voiced" : "unvoiced"
                let freq = frame.frequency.map { String(format: "%.1f", $0) } ?? "—"
                Text("Ref: \(freq) Hz (\(status))")
            } else {
                Text("Ref: —")
                    .foregroundStyle(.secondary)
            }
        }
    }

    var scoringRow: some View {
        Group {
            if let engine = scoringEngine {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Score: \(String(format: "%.1f", engine.overallScore))%")
                    Text("Log entries: \(engine.pitchLog.count)")
                    Text("Accuracy: \(engine.currentAccuracy.label)")
                        .foregroundStyle(engine.currentAccuracy.color)
                }
            }
        }
    }

    func startFPSCounter() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            fps = frameCount
            frameCount = 0
        }
    }
}

#Preview {
    PitchDebugOverlay(
        pitchDetector: PitchDetector(engine: AudioEngine()),
        scoringEngine: nil,
        referenceStore: ReferencePitchStore(),
        currentTime: 10.0
    )
    .padding()
}
#endif
