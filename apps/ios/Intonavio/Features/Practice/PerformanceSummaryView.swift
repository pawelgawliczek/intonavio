import SwiftUI

/// Post-song performance summary shown when a full playthrough is recorded
/// (no seeks or loops). Provides quick stats and actions.
struct PerformanceSummaryView: View {
    let summary: PerformanceSummary
    var onViewProgress: () -> Void = {}
    var onPracticeWeakest: () -> Void = {}
    var onRestart: () -> Void = {}
    var onDone: () -> Void = {}

    @State private var displayedScore: Double = 0
    @State private var showContent = false
    @State private var confettiTrigger = false

    var body: some View {
        ZStack {
            Color.intonavioBackground.opacity(0.95)
                .ignoresSafeArea()
                .onTapGesture {} // absorb taps

            if summary.isNewBest && confettiTrigger {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack(spacing: 24) {
                Spacer()
                heroSection
                if showContent {
                    statsSection
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    actionButtons
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                Spacer()
            }
            .padding(.horizontal, 32)
        }
        .onAppear { startAnimations() }
    }
}

// MARK: - Hero Section

private extension PerformanceSummaryView {
    var heroSection: some View {
        VStack(spacing: 8) {
            if summary.isNewBest {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .font(.title2)
                        .foregroundStyle(.yellow)
                    Text("New Personal Best!")
                        .font(.title3.bold())
                        .foregroundStyle(.yellow)
                }
            } else {
                Text(encouragingMessage)
                    .font(.title3.bold())
                    .foregroundStyle(Color.intonavioIce)
            }

            Text("\(Int(displayedScore.rounded()))%")
                .font(.system(size: 64, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(summary.isNewBest ? .green : .white)
                .contentTransition(.numericText(value: displayedScore))

            if !summary.isNewBest, summary.previousBest > 0 {
                Text("Your best: \(Int(summary.previousBest.rounded()))%")
                    .font(.subheadline)
                    .foregroundStyle(Color.intonavioTextSecondary)
            }
        }
    }

    var encouragingMessage: String {
        let score = summary.score
        if score > 80 { return "Great performance!" }
        if score > 60 { return "Getting there!" }
        if score > 40 { return "Nice effort!" }
        return "Every session counts!"
    }
}

// MARK: - Stats Section

private extension PerformanceSummaryView {
    var statsSection: some View {
        VStack(spacing: 12) {
            if summary.phrasePBCount > 0 {
                statRow(
                    icon: "star.fill",
                    iconColor: .yellow,
                    text: "\(summary.phrasePBCount) of \(summary.totalPhrases) phrases were personal bests"
                )
            }

            if let delta = summary.deltaFromLastAttempt {
                let sign = delta >= 0 ? "+" : ""
                let color: Color = delta >= 0 ? .green : .red
                statRow(
                    icon: delta >= 0 ? "arrow.up.right" : "arrow.down.right",
                    iconColor: color,
                    text: "\(sign)\(Int(delta.rounded()))% from last attempt"
                )
            }

            if !summary.isNewBest, summary.previousBest > 0 {
                let gap = summary.previousBest - summary.score
                if gap > 0 {
                    statRow(
                        icon: "target",
                        iconColor: .orange,
                        text: "\(Int(gap.rounded()))% away from your best"
                    )
                }
            }

            if summary.improvingStreak > 1 {
                statRow(
                    icon: "flame.fill",
                    iconColor: .orange,
                    text: "\(summary.improvingStreak) sessions improving in a row!"
                )
            }
        }
        .padding(16)
        .background(Color.intonavioSurface, in: RoundedRectangle(cornerRadius: 12))
    }

    func statRow(icon: String, iconColor: Color, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.intonavioTextPrimary)
            Spacer()
        }
    }
}

// MARK: - Action Buttons

private extension PerformanceSummaryView {
    var actionButtons: some View {
        VStack(spacing: 10) {
            Button("View Progress", action: onViewProgress)
                .buttonStyle(SecondaryButtonStyle())

            if summary.weakestPhraseIndex != nil {
                Button("Practice Weakest Phrase", action: onPracticeWeakest)
                    .buttonStyle(SecondaryButtonStyle())
            }

            HStack(spacing: 12) {
                Button("Restart", action: onRestart)
                    .buttonStyle(SecondaryButtonStyle())
                Button("Done", action: onDone)
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
    }
}

// MARK: - Animations

private extension PerformanceSummaryView {
    func startAnimations() {
        // Counter roll
        withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
            displayedScore = summary.score
        }

        // Reveal stats + buttons
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.8)) {
            showContent = true
        }

        if summary.isNewBest {
            confettiTrigger = true

            #if os(iOS)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
            #endif
        }
    }
}

// MARK: - Data Model

/// Computed summary data for the post-song performance overlay.
struct PerformanceSummary {
    let score: Double
    let isNewBest: Bool
    let previousBest: Double
    let totalPhrases: Int
    let phrasePBCount: Int
    let deltaFromLastAttempt: Double?
    let improvingStreak: Int
    let weakestPhraseIndex: Int?
    let weakestPhraseScore: Double?
}

#Preview("New Best") {
    PerformanceSummaryView(
        summary: PerformanceSummary(
            score: 87,
            isNewBest: true,
            previousBest: 82,
            totalPhrases: 12,
            phrasePBCount: 5,
            deltaFromLastAttempt: 8,
            improvingStreak: 3,
            weakestPhraseIndex: 2,
            weakestPhraseScore: 34
        )
    )
}

#Preview("Regular Run") {
    PerformanceSummaryView(
        summary: PerformanceSummary(
            score: 65,
            isNewBest: false,
            previousBest: 82,
            totalPhrases: 12,
            phrasePBCount: 1,
            deltaFromLastAttempt: -3,
            improvingStreak: 0,
            weakestPhraseIndex: 7,
            weakestPhraseScore: 28
        )
    )
}
