import SwiftUI

/// Two-line karaoke overlay showing current and next lyric lines.
struct LyricsOverlayView: View {
    let currentLine: String?
    let nextLine: String?

    var body: some View {
        VStack(spacing: 2) {
            Text(currentLine ?? "")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(nextLine ?? "")
                .font(.caption)
                .foregroundStyle(Color.intonavioTextSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .padding(.horizontal, 12)
        .background(Color.intonavioBackground.opacity(0.85))
    }
}

#Preview {
    VStack(spacing: 0) {
        LyricsOverlayView(
            currentLine: "Hello darkness, my old friend",
            nextLine: "I've come to talk with you again"
        )
        LyricsOverlayView(
            currentLine: nil,
            nextLine: "First line coming up..."
        )
    }
}
