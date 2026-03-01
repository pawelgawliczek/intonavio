import SwiftUI

/// Row component showing a phrase score as a colored bar with best score badge.
struct PhraseScoreRowView: View {
    let phraseNumber: Int
    let bestScore: Double
    let totalAttempts: Int

    var body: some View {
        HStack(spacing: 12) {
            Text("Phrase \(phraseNumber)")
                .font(.subheadline.monospacedDigit())
                .frame(width: 80, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.intonavioSurface)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: geometry.size.width * fillFraction)
                }
            }
            .frame(height: 12)

            Text("\(Int(bestScore.rounded()))%")
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(barColor)
                .frame(width: 44, alignment: .trailing)
        }
    }
}

// MARK: - Computed

private extension PhraseScoreRowView {
    var fillFraction: CGFloat {
        CGFloat(max(0, min(bestScore, 100)) / 100)
    }

    var barColor: Color {
        if bestScore > 80 { return .green }
        if bestScore > 50 { return .yellow }
        if bestScore > 30 { return .orange }
        return .gray
    }
}

#Preview {
    VStack(spacing: 8) {
        PhraseScoreRowView(phraseNumber: 1, bestScore: 95, totalAttempts: 5)
        PhraseScoreRowView(phraseNumber: 2, bestScore: 72, totalAttempts: 3)
        PhraseScoreRowView(phraseNumber: 3, bestScore: 45, totalAttempts: 2)
        PhraseScoreRowView(phraseNumber: 4, bestScore: 15, totalAttempts: 1)
    }
    .padding()
}
