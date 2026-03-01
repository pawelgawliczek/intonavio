import SwiftUI

/// Floating capsule toast showing phrase score after each phrase completes.
struct PhraseScoreToastView: View {
    let score: Double
    let phraseIndex: Int
    let totalPhrases: Int
    let isNewBest: Bool

    var body: some View {
        HStack(spacing: 10) {
            scoreLabel
            phraseLabel
            if isNewBest {
                newBestBadge
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.intonavioSurface, in: Capsule())
        .transition(.asymmetric(
            insertion: .scale(scale: 0.5).combined(with: .opacity),
            removal: .opacity
        ))
    }
}

// MARK: - Subviews

private extension PhraseScoreToastView {
    var scoreLabel: some View {
        Text("\(Int(score.rounded()))%")
            .font(.title3.bold().monospacedDigit())
            .foregroundStyle(scoreColor)
    }

    var phraseLabel: some View {
        Text("Phrase \(phraseIndex + 1)/\(totalPhrases)")
            .font(.caption.monospacedDigit())
            .foregroundStyle(Color.intonavioTextSecondary)
    }

    var newBestBadge: some View {
        Label("New Best!", systemImage: "star.fill")
            .font(.caption.bold())
            .foregroundStyle(.yellow)
    }

    var scoreColor: Color {
        if score > 80 { return .green }
        if score > 50 { return .yellow }
        if score > 30 { return .orange }
        return .gray
    }
}

/// Larger celebration overlay for new song best.
struct SongBestToastView: View {
    let score: Double
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 8) {
            Label("New Song Best!", systemImage: "star.fill")
                .font(.headline.bold())
                .foregroundStyle(.yellow)

            Text("\(Int(score.rounded()))%")
                .font(.largeTitle.bold().monospacedDigit())
                .foregroundStyle(.green)
                .scaleEffect(pulseScale)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        pulseScale = 1.3
                    }
                    withAnimation(.easeInOut(duration: 0.3).delay(0.3)) {
                        pulseScale = 1.0
                    }
                }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.intonavioSurface, in: RoundedRectangle(cornerRadius: 16))
        .transition(.asymmetric(
            insertion: .scale(scale: 0.5).combined(with: .opacity),
            removal: .opacity
        ))
    }
}

#Preview {
    VStack(spacing: 20) {
        PhraseScoreToastView(score: 92, phraseIndex: 2, totalPhrases: 12, isNewBest: true)
        PhraseScoreToastView(score: 65, phraseIndex: 5, totalPhrases: 12, isNewBest: false)
        PhraseScoreToastView(score: 28, phraseIndex: 8, totalPhrases: 12, isNewBest: false)
        SongBestToastView(score: 87)
    }
    .padding()
    .background(Color.black)
}
