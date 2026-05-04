import Foundation

enum SongArchiveStore {
    private static let fileURL: URL = {
        let caches = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )[0]
        return caches
            .appendingPathComponent("library", isDirectory: true)
            .appendingPathComponent("archived-song-ids.json")
    }()

    static func archivedSongIds() -> Set<String> {
        guard let data = try? Data(contentsOf: fileURL),
              let ids = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return Set(ids)
    }

    static func save(_ ids: Set<String>) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(ids.sorted())
            try data.write(to: fileURL)
        } catch {
            AppLogger.library.error(
                "Failed to save archived songs: \(error.localizedDescription)"
            )
        }
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
