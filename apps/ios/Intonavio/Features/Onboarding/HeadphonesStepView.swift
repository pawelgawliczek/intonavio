import SwiftUI

/// Screen 2: Headphones advisory with live route detection.
struct HeadphonesStepView: View {
    let detected: Bool
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "headphones")
                .font(.system(size: 64))
                .foregroundStyle(Color.intonavioIce)

            Text("Plug in headphones\nwith a microphone")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                infoText(
                    "Intonavio listens to your voice while "
                    + "playing music. Without headphones, the "
                    + "speaker audio bleeds into the mic and "
                    + "reduces pitch detection accuracy."
                )
                infoText(
                    "It still works without them, but "
                    + "headphones give you the best experience."
                )
                infoText(
                    "Wired earbuds with a mic work best. "
                    + "AirPods work too — just avoid speakers."
                )
            }
            .padding(.horizontal, 32)

            routeIndicator
                .padding(.top, 8)

            Spacer()

            Button("Continue", action: onContinue)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 40)
        }
        .padding(.bottom, 48)
    }

    private var routeIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: detected ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(detected ? .green : .orange)
            Text(detected ? "Headphones detected" : "No headphones detected")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(detected ? .green : .orange)
        }
    }

    private func infoText(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Color.intonavioTextSecondary)
            .multilineTextAlignment(.center)
    }
}

#Preview {
    HeadphonesStepView(detected: false, onContinue: {})
        .background(Color.intonavioBackground)
}
