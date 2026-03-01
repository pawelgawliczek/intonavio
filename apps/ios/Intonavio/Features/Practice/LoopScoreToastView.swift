import SwiftUI

/// Floating toast that shows the score after each loop pass with
/// a better/worse delta compared to the previous pass.
struct LoopScoreToastView: View {
    let score: Double
    let change: ScoreChange?

    var body: some View {
        HStack(spacing: 8) {
            Text("\(Int(score.rounded()))%")
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(.white)

            if let change {
                changeLabel(change)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.intonavioSurface, in: Capsule())
        .transition(.opacity.combined(with: .scale(scale: 0.8)))
    }
}

// MARK: - Change Label

private extension LoopScoreToastView {
    @ViewBuilder
    func changeLabel(_ change: ScoreChange) -> some View {
        switch change {
        case .better(let delta):
            Label("+\(Int(delta.rounded()))", systemImage: "arrow.up")
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(.green)
        case .worse(let delta):
            Label("-\(Int(delta.rounded()))", systemImage: "arrow.down")
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(.red)
        case .same:
            Label("=", systemImage: "equal")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        LoopScoreToastView(score: 78, change: .better(5))
        LoopScoreToastView(score: 73, change: .worse(3))
        LoopScoreToastView(score: 78, change: .same)
        LoopScoreToastView(score: 65, change: nil)
    }
    .padding()
    .background(Color.black)
}
