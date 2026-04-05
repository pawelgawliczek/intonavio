import SwiftUI

/// Screen 4: Live pitch detection — the "wow moment."
/// Shows a simplified pitch indicator, no piano roll reference.
struct PitchTestStepView: View {
    let noteName: String?
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Sing any note")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("Hold it for a moment")
                .font(.subheadline)
                .foregroundStyle(Color.intonavioTextSecondary)

            pitchDisplay
                .frame(height: 160)
                .padding(.horizontal, 40)

            Spacer()

            Button("Continue", action: onContinue)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 40)
        }
        .padding(.bottom, 48)
    }

    private var pitchDisplay: some View {
        VStack(spacing: 16) {
            Text(noteName ?? "--")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(
                    noteName != nil
                        ? Color.intonavioIce
                        : Color.intonavioTextSecondary
                )
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.1), value: noteName)

            if noteName != nil {
                listeningIndicator(active: true)
            } else {
                listeningIndicator(active: false)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.intonavioSurface)
        )
    }

    private func listeningIndicator(active: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(active ? Color.green : Color.intonavioTextSecondary)
                .frame(width: 8, height: 8)
            Text(active ? "Listening" : "Waiting for voice...")
                .font(.caption)
                .foregroundStyle(Color.intonavioTextSecondary)
        }
    }
}

#Preview {
    PitchTestStepView(noteName: "C4", onContinue: {})
        .background(Color.intonavioBackground)
}
