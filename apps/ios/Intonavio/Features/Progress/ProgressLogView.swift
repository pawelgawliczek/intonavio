import SwiftUI

/// Shows score history for a song: overall best + per-phrase breakdown.
struct ProgressLogView: View {
    let songId: String
    let totalPhrases: Int
    let scoreRepository: ScoreRepository?
    var instrumentalURL: URL?
    var onPhraseTap: ((Int) -> Void)?

    @State private var isShowingResetConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                scoreChartSection
                practiceFrequencySection
                songSummarySection
                bestTakeSection
                if totalPhrases > 0 {
                    phraseBreakdownSection
                }
                resetSection
            }
            .navigationTitle("Progress")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .confirmationDialog(
                "Reset all scores for this song?",
                isPresented: $isShowingResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset Scores", role: .destructive) {
                    scoreRepository?.deleteAllScores(songId: songId)
                    BestTakeStorage.delete(for: songId)
                }
            } message: {
                Text("This will delete all phrase and song scores across all difficulties. This cannot be undone.")
            }
        }
    }
}

// MARK: - Sections

private extension ProgressLogView {
    var scoreChartSection: some View {
        Section("Score History") {
            ScoreHistoryChartView(scores: songHistory)
        }
    }

    var practiceFrequencySection: some View {
        Section("Practice Activity") {
            PracticeFrequencyChartView(scores: allSongScores)
        }
    }

    var songSummarySection: some View {
        Section("Overall") {
            HStack {
                Label("Difficulty", systemImage: DifficultyLevel.current.icon)
                Spacer()
                Text(DifficultyLevel.current.label)
                    .foregroundStyle(.secondary)
            }

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

    @ViewBuilder
    var bestTakeSection: some View {
        Section("Best Take") {
            if BestTakeStorage.exists(for: songId), instrumentalURL != nil {
                BestTakeRowView(
                    songId: songId,
                    instrumentalURL: instrumentalURL
                )
            } else if instrumentalURL == nil {
                Text("Instrumental stem required for Best Take")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Sing the full song to save your best take")
                    .font(.caption)
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

                phraseRow(index: index, best: best, attempts: attempts)
            }
        }
    }

    var resetSection: some View {
        Section {
            Button(role: .destructive) {
                isShowingResetConfirmation = true
            } label: {
                Label("Reset Scores", systemImage: "trash")
            }
        }
    }

    func phraseRow(index: Int, best: Double, attempts: Int) -> some View {
        Button {
            onPhraseTap?(index)
        } label: {
            PhraseScoreRowView(
                phraseNumber: index + 1,
                bestScore: best,
                totalAttempts: attempts
            )
        }
        .tint(.primary)
    }
}

// MARK: - Data

private extension ProgressLogView {
    var songHistory: [ScoreRecord] {
        scoreRepository?.fetchHistory(songId: songId, phraseIndex: nil) ?? []
    }

    var allSongScores: [ScoreRecord] {
        scoreRepository?.fetchAllScores(songId: songId) ?? []
    }

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
    ProgressLogView(songId: "test", totalPhrases: 5, scoreRepository: nil, instrumentalURL: nil)
}
