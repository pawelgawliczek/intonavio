import Foundation
import OSLog

/// Local disk store for `PitchEditScript`, one JSON file per song under
/// `Documents/pitch-edits/<songId>.json`.
enum PitchEditScriptStore {
    private static let directoryName = "pitch-edits"

    private static func rootURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(directoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(
                    at: url,
                    withIntermediateDirectories: true
                )
            } catch {
                AppLogger.library.error(
                    "PitchEditScriptStore: failed to create root dir: \(error.localizedDescription)"
                )
            }
        }
        return url
    }

    private static func fileURL(songId: String) -> URL {
        rootURL().appendingPathComponent("\(songId).json")
    }

    private static func makeEncoder() -> JSONEncoder {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return enc
    }

    private static func makeDecoder() -> JSONDecoder {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }

    static func load(songId: String) -> PitchEditScript? {
        let url = fileURL(songId: songId)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try makeDecoder().decode(PitchEditScript.self, from: data)
        } catch {
            AppLogger.library.error(
                "PitchEditScriptStore: load failed for \(songId): \(error.localizedDescription)"
            )
            return nil
        }
    }

    static func save(_ script: PitchEditScript) throws {
        let url = fileURL(songId: script.songId)
        let data = try makeEncoder().encode(script)
        try data.write(to: url, options: .atomic)
    }

    static func delete(songId: String) {
        let url = fileURL(songId: songId)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            AppLogger.library.error(
                "PitchEditScriptStore: delete failed for \(songId): \(error.localizedDescription)"
            )
        }
    }

    static func exists(songId: String) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(songId: songId).path)
    }

    static func editedSongIds() -> Set<String> {
        let url = rootURL()
        guard
            let entries = try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil
            )
        else {
            return []
        }
        var result: Set<String> = []
        for entry in entries where entry.pathExtension == "json" {
            result.insert(entry.deletingPathExtension().lastPathComponent)
        }
        return result
    }
}
