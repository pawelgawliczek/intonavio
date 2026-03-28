import SwiftUI

/// A drop-in replacement for AsyncImage that caches downloaded images to disk.
struct CachedAsyncImage: View {
    let url: URL?
    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var hasFailed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(16 / 9, contentMode: .fill)
            } else if hasFailed {
                placeholder
            } else {
                placeholder.overlay { ProgressView() }
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.intonavioSurface)
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                Image(systemName: "music.note")
                    .foregroundStyle(Color.intonavioTextSecondary)
            }
    }

    private func loadImage() async {
        guard let url, !isLoading else { return }
        isLoading = true

        if let cached = ThumbnailCache.shared.load(for: url) {
            image = cached
            isLoading = false
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let downloaded = UIImage(data: data) else {
                hasFailed = true
                isLoading = false
                return
            }
            ThumbnailCache.shared.save(data, for: url)
            image = downloaded
        } catch {
            hasFailed = true
        }

        isLoading = false
    }
}

/// Simple disk cache for thumbnail images keyed by URL.
final class ThumbnailCache: Sendable {
    static let shared = ThumbnailCache()

    private let directory: URL = {
        let caches = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )[0]
        let dir = caches.appendingPathComponent("thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        return dir
    }()

    func load(for url: URL) -> UIImage? {
        let path = filePath(for: url)
        guard let data = try? Data(contentsOf: path) else { return nil }
        return UIImage(data: data)
    }

    func save(_ data: Data, for url: URL) {
        let path = filePath(for: url)
        try? data.write(to: path)
    }

    private func filePath(for url: URL) -> URL {
        let name = url.absoluteString.data(using: .utf8)!
            .base64EncodedString()
            .prefix(64)
        return directory.appendingPathComponent(String(name))
    }
}
