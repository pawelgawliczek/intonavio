import SwiftUI

/// Floating toast that shows the score after each loop pass with
/// a better/worse delta compared to the previous pass.
struct LoopScoreToastView: View {
    let score: Double
    let change: ScoreChange?

    @State private var flashOpacity: Double = 0
    @State private var arrowOffset: CGFloat = 0
    @State private var deltaOffset: CGFloat = 8
    @State private var deltaOpacity: Double = 0

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
        .background(
            Capsule()
                .fill(Color.intonavioSurface)
                .overlay(
                    Capsule()
                        .fill(flashColor.opacity(flashOpacity))
                )
        )
        .transition(.opacity.combined(with: .scale(scale: 0.8)))
        .onAppear { startAnimations() }
    }
}

// MARK: - Change Label

private extension LoopScoreToastView {
    @ViewBuilder
    func changeLabel(_ change: ScoreChange) -> some View {
        switch change {
        case .better(let delta):
            HStack(spacing: 2) {
                Image(systemName: "arrow.up")
                    .offset(y: arrowOffset)
                Text("+\(Int(delta.rounded()))")
                    .offset(y: deltaOffset)
                    .opacity(deltaOpacity)
            }
            .font(.subheadline.bold().monospacedDigit())
            .foregroundStyle(.green)

        case .worse(let delta):
            Label("-\(Int(delta.rounded()))", systemImage: "arrow.down")
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(.red)
                .opacity(deltaOpacity)

        case .same:
            Label("=", systemImage: "equal")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .opacity(deltaOpacity)
        }
    }

    var flashColor: Color {
        switch change {
        case .better: .green
        case .worse: .red
        default: .clear
        }
    }
}

// MARK: - Animations

private extension LoopScoreToastView {
    func startAnimations() {
        // Delta slide in
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.1)) {
            deltaOffset = 0
            deltaOpacity = 1
        }

        guard case .better = change else {
            // Gentle fade for worse/same
            if case .worse = change {
                withAnimation(.easeIn(duration: 0.15)) {
                    flashOpacity = 0.15
                }
                withAnimation(.easeOut(duration: 0.4).delay(0.15)) {
                    flashOpacity = 0
                }
            }
            withAnimation(.easeIn(duration: 0.3)) {
                deltaOpacity = 1
            }
            return
        }

        // Green flash
        withAnimation(.easeIn(duration: 0.1)) {
            flashOpacity = 0.2
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
            flashOpacity = 0
        }

        // Arrow bounce (3 hops)
        bounceArrow(count: 3)
    }

    func bounceArrow(count: Int) {
        guard count > 0 else { return }
        let magnitude = CGFloat(count) * -2.5
        withAnimation(.easeOut(duration: 0.1)) {
            arrowOffset = magnitude
        }
        withAnimation(.easeIn(duration: 0.1).delay(0.1)) {
            arrowOffset = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            bounceArrow(count: count - 1)
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
