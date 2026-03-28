import SwiftUI

/// Full-panel lyrics display showing previous, current, and next lines.
/// Replaces the YouTube video when in lyrics layout mode.
struct LyricsPanelView: View {
    let previousLine: String?
    let currentLine: String?
    let nextLine: String?

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Text(previousLine ?? "")
                .font(.body)
                .foregroundStyle(Color.intonavioTextSecondary.opacity(0.5))
                .lineLimit(2)
                .minimumScaleFactor(0.6)

            Text(currentLine ?? "")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

            Text(nextLine ?? "")
                .font(.body)
                .foregroundStyle(Color.intonavioTextSecondary.opacity(0.7))
                .lineLimit(2)
                .minimumScaleFactor(0.6)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .background(Color.intonavioBackground)
    }
}

#Preview {
    LyricsPanelView(
        previousLine: "Because a vision softly creeping",
        currentLine: "Hello darkness, my old friend",
        nextLine: "I've come to talk with you again"
    )
    .frame(height: 200)
}
