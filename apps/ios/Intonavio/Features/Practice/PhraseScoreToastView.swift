import SwiftUI

/// Floating capsule toast showing phrase score after each phrase completes.
struct PhraseScoreToastView: View {
    let score: Double
    let phraseIndex: Int
    let totalPhrases: Int
    let isNewBest: Bool

    @State private var displayedScore: Double = 0
    @State private var starRotation: Double = 0
    @State private var starScale: CGFloat = 0.1
    @State private var borderOpacity: Double = 0
    @State private var shimmerOffset: CGFloat = -100

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
        .background(
            Capsule()
                .fill(Color.intonavioSurface)
                .overlay(
                    isNewBest
                        ? Capsule()
                            .strokeBorder(Color.yellow.opacity(borderOpacity), lineWidth: 1.5)
                        : nil
                )
        )
        .transition(.asymmetric(
            insertion: .scale(scale: 0.5).combined(with: .opacity),
            removal: .opacity
        ))
        .onAppear { startAnimations() }
    }
}

// MARK: - Subviews

private extension PhraseScoreToastView {
    var scoreLabel: some View {
        Text("\(Int(displayedScore.rounded()))%")
            .font(.title3.bold().monospacedDigit())
            .foregroundStyle(scoreColor)
            .contentTransition(.numericText(value: displayedScore))
    }

    var phraseLabel: some View {
        Text("Phrase \(phraseIndex + 1)/\(totalPhrases)")
            .font(.caption.monospacedDigit())
            .foregroundStyle(Color.intonavioTextSecondary)
    }

    var newBestBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill")
                .rotationEffect(.degrees(starRotation))
                .scaleEffect(starScale)

            Text("New Best!")
                .overlay(shimmerOverlay)
        }
        .font(.caption.bold())
        .foregroundStyle(.yellow)
    }

    var shimmerOverlay: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [.clear, .white.opacity(0.6), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 30)
            .offset(x: shimmerOffset)
            .frame(width: geo.size.width, alignment: .leading)
            .clipped()
            .blendMode(.sourceAtop)
        }
    }

    var scoreColor: Color {
        if score > 80 { return .green }
        if score > 50 { return .yellow }
        if score > 30 { return .orange }
        return .gray
    }
}

// MARK: - Animations

private extension PhraseScoreToastView {
    func startAnimations() {
        // Counter roll
        withAnimation(.easeOut(duration: 0.4)) {
            displayedScore = score
        }

        guard isNewBest else { return }

        // Star burst
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            starScale = 1.2
            starRotation = 360
        }
        withAnimation(.spring(response: 0.2, dampingFraction: 0.7).delay(0.3)) {
            starScale = 1.0
        }

        // Gold border pulse
        withAnimation(.easeIn(duration: 0.2)) {
            borderOpacity = 0.8
        }
        withAnimation(.easeOut(duration: 0.8).delay(0.5)) {
            borderOpacity = 0
        }

        // Shimmer sweep
        withAnimation(.easeInOut(duration: 0.6).delay(0.2)) {
            shimmerOffset = 100
        }
    }
}

/// Larger celebration overlay for new song best.
struct SongBestToastView: View {
    let score: Double
    let isNewBest: Bool

    @State private var displayedScore: Double = 0
    @State private var ringScale: CGFloat = 0.3
    @State private var ringOpacity: Double = 1.0
    @State private var starRotation: Double = 0
    @State private var starScale: CGFloat = 0.5
    @State private var confettiTrigger = false

    var body: some View {
        ZStack {
            // Expanding glow ring
            if isNewBest {
                Circle()
                    .stroke(Color.yellow.opacity(ringOpacity), lineWidth: 3)
                    .scaleEffect(ringScale)
                    .frame(width: 120, height: 120)
            }

            VStack(spacing: 8) {
                if isNewBest {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .font(.headline)
                            .foregroundStyle(.yellow)
                            .rotationEffect(.degrees(starRotation))
                            .scaleEffect(starScale)

                        Text("New Song Best!")
                            .font(.headline.bold())
                            .foregroundStyle(.yellow)
                    }
                }

                Text("\(Int(displayedScore.rounded()))%")
                    .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(isNewBest ? .green : .white)
                    .contentTransition(.numericText(value: displayedScore))
            }

            if isNewBest && confettiTrigger {
                ConfettiView()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.intonavioSurface, in: RoundedRectangle(cornerRadius: 16))
        .transition(.asymmetric(
            insertion: .scale(scale: 0.5).combined(with: .opacity),
            removal: .opacity
        ))
        .onAppear { startAnimations() }
    }
}

// MARK: - Song Best Animations

private extension SongBestToastView {
    func startAnimations() {
        // Counter roll
        withAnimation(.easeOut(duration: 0.8)) {
            displayedScore = score
        }

        guard isNewBest else { return }

        // Crown spin + bounce
        withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
            starScale = 1.2
            starRotation = 360
        }
        withAnimation(.spring(response: 0.2, dampingFraction: 0.7).delay(0.4)) {
            starScale = 1.0
        }

        // Expanding ring
        withAnimation(.easeOut(duration: 0.8)) {
            ringScale = 3.0
            ringOpacity = 0
        }

        // Confetti
        confettiTrigger = true

        // Haptic
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
}

// MARK: - Confetti

/// Canvas-based confetti burst that animates 30 particles outward with gravity.
struct ConfettiView: View {
    @State private var time: Double = 0

    private let particles: [ConfettiParticle] = (0..<30).map { _ in
        ConfettiParticle()
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate - startTime
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                for particle in particles {
                    let progress = min(elapsed / particle.lifetime, 1.0)
                    guard progress < 1.0 else { continue }

                    let x = center.x + particle.velocityX * CGFloat(elapsed)
                    let y = center.y + particle.velocityY * CGFloat(elapsed)
                        + 150 * CGFloat(elapsed * elapsed) // gravity
                    let opacity = 1.0 - progress
                    let rotation = Angle.degrees(particle.spin * elapsed)

                    context.opacity = opacity
                    context.translateBy(x: x, y: y)
                    context.rotate(by: rotation)

                    let rect = CGRect(
                        x: -particle.size / 2,
                        y: -particle.size / 2,
                        width: particle.size,
                        height: particle.size
                    )

                    switch particle.shape {
                    case 0:
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .color(particle.color)
                        )
                    case 1:
                        context.fill(
                            Path(rect),
                            with: .color(particle.color)
                        )
                    default:
                        context.fill(
                            starPath(in: rect),
                            with: .color(particle.color)
                        )
                    }

                    context.rotate(by: -rotation)
                    context.translateBy(x: -x, y: -y)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { startTime = Date.timeIntervalSinceReferenceDate }
    }

    @State private var startTime: Double = Date.timeIntervalSinceReferenceDate

    private func starPath(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = rect.width / 2
        let innerRadius = outerRadius * 0.4
        var path = Path()
        for i in 0..<10 {
            let angle = Angle.degrees(Double(i) * 36.0 - 90.0)
            let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle.radians)) * radius,
                y: center.y + CGFloat(sin(angle.radians)) * radius
            )
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

private struct ConfettiParticle {
    let velocityX: CGFloat
    let velocityY: CGFloat
    let color: Color
    let size: CGFloat
    let shape: Int
    let spin: Double
    let lifetime: Double

    init() {
        let angle = Double.random(in: 0..<360)
        let speed = CGFloat.random(in: 80...200)
        velocityX = cos(angle * .pi / 180) * speed
        velocityY = sin(angle * .pi / 180) * speed - 100 // bias upward
        color = [Color.yellow, .green, .cyan, .pink, .orange, .purple].randomElement()!
        size = CGFloat.random(in: 4...8)
        shape = Int.random(in: 0...2)
        spin = Double.random(in: 200...600) * (Bool.random() ? 1 : -1)
        lifetime = Double.random(in: 1.0...1.8)
    }
}

#Preview {
    VStack(spacing: 20) {
        PhraseScoreToastView(score: 92, phraseIndex: 2, totalPhrases: 12, isNewBest: true)
        PhraseScoreToastView(score: 65, phraseIndex: 5, totalPhrases: 12, isNewBest: false)
        PhraseScoreToastView(score: 28, phraseIndex: 8, totalPhrases: 12, isNewBest: false)
        SongBestToastView(score: 87, isNewBest: true)
        SongBestToastView(score: 72, isNewBest: false)
    }
    .padding()
    .background(Color.black)
}
