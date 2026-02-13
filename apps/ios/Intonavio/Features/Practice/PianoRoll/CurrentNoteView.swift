import SwiftUI

/// Displays the current detected note name and cents deviation.
struct CurrentNoteView: View {
    let noteName: String?
    let centsDeviation: Float
    let accuracy: PitchAccuracy
    let score: Double

    var body: some View {
        HStack(spacing: 16) {
            noteDisplay
            Spacer()
            scoreDisplay
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

// MARK: - Subviews

private extension CurrentNoteView {
    var noteDisplay: some View {
        HStack(spacing: 8) {
            Text(noteName ?? "—")
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(accuracy.color)
                .frame(minWidth: 44)

            if noteName != nil {
                centsIndicator
            }
        }
    }

    var centsIndicator: some View {
        let sign = centsDeviation >= 0 ? "+" : ""
        let text = "\(sign)\(Int(centsDeviation))¢"

        return Text(text)
            .font(.caption.monospacedDigit())
            .foregroundStyle(accuracy.color.opacity(0.8))
    }

    var scoreDisplay: some View {
        HStack(spacing: 4) {
            Text("Score")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(Int(score))")
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    VStack {
        CurrentNoteView(noteName: "C4", centsDeviation: 5, accuracy: .excellent, score: 85)
        CurrentNoteView(noteName: "A3", centsDeviation: -23, accuracy: .good, score: 72)
        CurrentNoteView(noteName: nil, centsDeviation: 0, accuracy: .unvoiced, score: 0)
    }
    .padding()
}
