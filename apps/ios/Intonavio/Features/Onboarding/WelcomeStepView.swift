import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Screen 1: App icon, name, and three value props.
struct WelcomeStepView: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            appIcon
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 22))

            Text("Intonavio")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            VStack(spacing: 12) {
                valueProp("Sing along to any song")
                valueProp("See your pitch in real time")
                valueProp("Get better, fast")
            }

            Spacer()

            Button("Get Started", action: onContinue)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 40)
        }
        .padding(.bottom, 48)
    }

    @ViewBuilder
    private var appIcon: some View {
        #if os(iOS)
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let name = files.last,
           let uiImage = UIImage(named: name)
        {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "waveform.path")
                .font(.system(size: 64))
                .foregroundStyle(Color.intonavioIce)
        }
        #else
        Image(systemName: "waveform.path")
            .font(.system(size: 64))
            .foregroundStyle(Color.intonavioIce)
        #endif
    }

    private func valueProp(_ text: String) -> some View {
        Text(text)
            .font(.title3)
            .foregroundStyle(Color.intonavioTextSecondary)
    }
}

#Preview {
    WelcomeStepView(onContinue: {})
        .background(Color.intonavioBackground)
}
