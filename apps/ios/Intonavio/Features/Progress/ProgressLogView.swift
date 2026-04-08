import SwiftUI

/// Shows score history for a song: overall best + per-phrase breakdown.
struct ProgressLogView: View {
    let songId: String
    let totalPhrases: Int
    let scoreRepository: ScoreRepository?
    var instrumentalURL: URL?
    var variants: [SongVariant] = []
    var activeVariantId: String?
    var onSwitchVariant: ((SongVariant) -> Void)?
    var onGenerateVariant: ((StemSource) async -> Void)?
    var onPhraseTap: ((Int) -> Void)?
    var onEditReference: (() -> Void)?

    @State private var isShowingResetConfirmation = false
    @State private var isShowingEditConfirmation = false
    @State private var isGeneratingVariant = false
    @State private var variantError: String?

    var body: some View {
        NavigationStack {
            List {
                scoreChartSection
                practiceFrequencySection
                if !variants.isEmpty {
                    sourceSection
                }
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
            .confirmationDialog(
                "Edit reference?",
                isPresented: $isShowingEditConfirmation,
                titleVisibility: .visible
            ) {
                Button("Continue", role: .destructive) { onEditReference?() }
            } message: {
                Text("Editing the reference will reset all scores for this song. This can't be undone.")
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

    var sourceSection: some View {
        Section("Source") {
            if readyVariants.count >= 2 {
                Picker("Active", selection: Binding(
                    get: { activeVariant?.id ?? readyVariants.first?.id ?? "" },
                    set: { newId in
                        if let v = readyVariants.first(where: { $0.id == newId }) {
                            onSwitchVariant?(v)
                        }
                    }
                )) {
                    ForEach(readyVariants) { variant in
                        Text(variant.source.displayName).tag(variant.id)
                    }
                }
                .pickerStyle(.segmented)
                if let active = activeVariant {
                    Text(active.source.shortDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else if let active = activeVariant {
                HStack {
                    Label("Current", systemImage: "waveform.badge.magnifyingglass")
                    Spacer()
                    Text(active.source.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(active.source.shortDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            if readyVariants.count < 2, let other = otherVariantRow {
                switch other {
                case .existing(let variant):
                    HStack {
                        Label("Alternate", systemImage: "arrow.triangle.2.circlepath")
                        Spacer()
                        Text("\(variant.source.displayName) \(variant.status.rawValue.lowercased())")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                case .missing(let source):
                    Button {
                        generate(source)
                    } label: {
                        HStack {
                            Label(
                                "Process with \(source.displayName)",
                                systemImage: "plus.circle"
                            )
                            Spacer()
                            if isGeneratingVariant {
                                ProgressView().controlSize(.small)
                            }
                        }
                    }
                    .disabled(isGeneratingVariant || onGenerateVariant == nil)
                }
            }
            if let variantError {
                Text(variantError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Button {
                isShowingEditConfirmation = true
            } label: {
                Label("Edit reference…", systemImage: "slider.horizontal.below.rectangle")
            }
            .disabled(variants.isEmpty)
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
                    .foregroundStyle(Color.intonavioAmber)
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

    enum OtherVariantRow {
        case existing(SongVariant)
        case missing(StemSource)
    }

    var readyVariants: [SongVariant] {
        variants.filter { $0.status == .ready }
    }

    var activeVariant: SongVariant? {
        if let id = activeVariantId, let match = variants.first(where: { $0.id == id }) {
            return match
        }
        return variants.first
    }

    var otherVariantRow: OtherVariantRow? {
        if let other = variants.first(where: { $0.id != activeVariant?.id }) {
            return .existing(other)
        }
        let existing = Set(variants.map(\.source))
        if let missing = StemSource.allCases.first(where: { !existing.contains($0) }) {
            return .missing(missing)
        }
        return nil
    }

    func generate(_ source: StemSource) {
        guard let onGenerateVariant else { return }
        isGeneratingVariant = true
        variantError = nil
        Task { @MainActor in
            await onGenerateVariant(source)
            isGeneratingVariant = false
        }
    }

    func colorForScore(_ score: Double) -> Color {
        if score > 80 { return .intonavioAmber }
        if score > 50 { return .intonavioMagenta }
        if score > 30 { return .intonavioIce.opacity(0.7) }
        return .intonavioTextSecondary
    }
}

#Preview {
    ProgressLogView(songId: "test", totalPhrases: 5, scoreRepository: nil, instrumentalURL: nil)
}
