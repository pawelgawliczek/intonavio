import SwiftUI

struct SongGridItemView: View {
    let song: SongResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            thumbnail
            songInfo
        }
    }
}

// MARK: - Subviews

private extension SongGridItemView {
    var thumbnail: some View {
        AsyncImage(url: URL(string: song.thumbnailUrl)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(16 / 9, contentMode: .fill)
            case .failure:
                placeholder
            default:
                placeholder.overlay { ProgressView() }
            }
        }
        .frame(height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .topTrailing) {
            SongStatusBadge(status: song.status.rawValue)
                .padding(6)
        }
    }

    var placeholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.2))
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                Image(systemName: "music.note")
                    .foregroundStyle(.secondary)
            }
    }

    var songInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(song.title)
                .font(.caption)
                .lineLimit(2)
            if let artist = song.artist, !artist.isEmpty {
                Text(artist)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if song.duration > 0 {
                Text(formatDuration(song.duration))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

#Preview {
    SongGridItemView(song: Fixtures.readySong)
        .frame(width: 160)
}
