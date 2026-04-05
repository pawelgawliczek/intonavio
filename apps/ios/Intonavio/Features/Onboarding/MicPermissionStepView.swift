import SwiftUI

/// Screen 3: Microphone permission request with fallback for denial.
struct MicPermissionStepView: View {
    let granted: Bool
    let denied: Bool
    var onRequestPermission: () -> Void
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "mic.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.intonavioIce)

            Text("Allow microphone access")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text(
                "Intonavio uses your mic to detect your pitch "
                + "while you sing. Nothing is recorded or sent "
                + "anywhere."
            )
            .font(.subheadline)
            .foregroundStyle(Color.intonavioTextSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)

            if denied {
                deniedView
            }

            Spacer()

            if granted {
                Button("Continue", action: onContinue)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 40)
            } else if denied {
                Button("Continue without mic", action: onContinue)
                    .buttonStyle(SecondaryButtonStyle())
                    .padding(.horizontal, 40)
            } else {
                Button("Allow", action: onRequestPermission)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 40)
            }
        }
        .padding(.bottom, 48)
        .onChange(of: granted) { _, isGranted in
            if isGranted {
                onContinue()
            }
        }
    }

    private var deniedView: some View {
        VStack(spacing: 12) {
            Text(
                "Microphone access is required for pitch "
                + "detection. You can enable it in Settings."
            )
            .font(.subheadline)
            .foregroundStyle(.orange)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)

            Button("Open Settings") {
                #if os(iOS)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                #endif
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.intonavioIce)
        }
    }
}

#Preview {
    MicPermissionStepView(
        granted: false, denied: false,
        onRequestPermission: {}, onContinue: {}
    )
    .background(Color.intonavioBackground)
}
