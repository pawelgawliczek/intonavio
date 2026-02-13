import SwiftUI

struct SongStatusBadge: View {
    let status: String

    var body: some View {
        Text(status)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor, in: Capsule())
            .foregroundStyle(.white)
    }

    private var backgroundColor: Color {
        switch status {
        case "READY": .green
        case "FAILED": .red
        case "QUEUED", "DOWNLOADING", "SPLITTING", "ANALYZING": .orange
        default: .gray
        }
    }
}

#Preview {
    HStack {
        SongStatusBadge(status: "READY")
        SongStatusBadge(status: "QUEUED")
        SongStatusBadge(status: "FAILED")
    }
}
