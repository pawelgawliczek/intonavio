import SwiftUI

/// Displays the current detected note name, cents deviation, score, and phrase info.
struct CurrentNoteView: View {
    let noteName: String?
    let centsDeviation: Float
    let accuracy: PitchAccuracy
    let score: Double
    var phraseIndex: Int?
    var totalPhrases: Int = 0

    var body: some View {
        HStack(spacing: 16) {
            noteDisplay
            Spacer()
            if totalPhrases > 0, let index = phraseIndex {
                phraseIndicator(index: index)
            }
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
                .foregroundStyle(Color.intonavioTextSecondary)
            Text("\(Int(score))")
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(scoreColor)
        }
    }

    func phraseIndicator(index: Int) -> some View {
        Text("Phrase \(index + 1)/\(totalPhrases)")
            .font(.caption2.monospacedDigit())
            .foregroundStyle(Color.intonavioTextSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.intonavioSurface, in: Capsule())
    }

    var scoreColor: Color {
        if score > 80 { return .green }
        if score > 50 { return .yellow }
        if score > 30 { return .orange }
        return .primary
    }
}

#Preview {
    VStack {
        CurrentNoteView(noteName: "C4", centsDeviation: 5, accuracy: .excellent, score: 85,
                        phraseIndex: 2, totalPhrases: 12)
        CurrentNoteView(noteName: "A3", centsDeviation: -15, accuracy: .good, score: 72)
        CurrentNoteView(noteName: nil, centsDeviation: 0, accuracy: .unvoiced, score: 0)
    }
    .padding()
}
