import SwiftUI

/// Shows score history for a song: overall best + per-phrase breakdown.
struct ProgressLogView: View {
    let songId: String
    let totalPhrases: Int
    let scoreRepository: ScoreRepository?

    var body: some View {
        NavigationStack {
            List {
                songSummarySection
                if totalPhrases > 0 {
                    phraseBreakdownSection
                }
            }
            .navigationTitle("Progress")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}

// MARK: - Sections

private extension ProgressLogView {
    var songSummarySection: some View {
        Section("Overall") {
            HStack {
                Label("Best Score", systemImage: "star.fill")
                    .foregroundStyle(.yellow)
                Spacer()
                Text("\(Int(songBestScore.rounded()))%")
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(colorForScore(songBestScore))
            }

            HStack {
                Label("Attempts", systemImage: "arrow.counterclockwise")
                Spacer()
                Text("\(songAttemptCount)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    var phraseBreakdownSection: some View {
        Section("Phrases") {
            ForEach(0..<totalPhrases, id: \.self) { index in
                let best = scoreRepository?.fetchBestScore(
                    songId: songId, phraseIndex: index
                ) ?? 0
                let attempts = scoreRepository?.fetchHistory(
                    songId: songId, phraseIndex: index, limit: 1000
                ).count ?? 0

                PhraseScoreRowView(
                    phraseNumber: index + 1,
                    bestScore: best,
                    totalAttempts: attempts
                )
            }
        }
    }
}

// MARK: - Data

private extension ProgressLogView {
    var songBestScore: Double {
        scoreRepository?.fetchBestScore(songId: songId, phraseIndex: nil) ?? 0
    }

    var songAttemptCount: Int {
        scoreRepository?.fetchHistory(songId: songId, phraseIndex: nil, limit: 1000).count ?? 0
    }

    func colorForScore(_ score: Double) -> Color {
        if score > 80 { return .green }
        if score > 50 { return .yellow }
        if score > 30 { return .orange }
        return .gray
    }
}

#Preview {
    ProgressLogView(songId: "test", totalPhrases: 5, scoreRepository: nil)
}
