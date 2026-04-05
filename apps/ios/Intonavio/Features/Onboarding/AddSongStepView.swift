import SwiftUI

/// Screen 5: Prompt to add the first song or skip.
struct AddSongStepView: View {
    var onComplete: () -> Void

    @Environment(AppState.self) private var appState
    @State private var showAddSheet = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "music.note")
                .font(.system(size: 64))
                .foregroundStyle(Color.intonavioIce)

            Text("Pick a song to practice")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text(
                "Search for any song on YouTube, "
                + "or choose from the catalog."
            )
            .font(.subheadline)
            .foregroundStyle(Color.intonavioTextSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button("Search YouTube", action: onComplete)
                    .buttonStyle(PrimaryButtonStyle())

                Button("Skip for now", action: onComplete)
                    .font(.subheadline)
                    .foregroundStyle(Color.intonavioTextSecondary)
            }
            .padding(.horizontal, 40)
        }
        .padding(.bottom, 48)
    }
}

#Preview {
    AddSongStepView(onComplete: {})
        .environment(AppState())
        .background(Color.intonavioBackground)
}
