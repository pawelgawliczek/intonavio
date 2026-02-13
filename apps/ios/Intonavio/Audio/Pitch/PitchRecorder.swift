#if DEBUG
import Foundation

/// Records detected pitches to disk for offline analysis.
/// Debug-only utility for validating pitch detection accuracy.
final class PitchRecorder {
    private var entries: [RecorderEntry] = []
    private(set) var isRecording = false
    private let fileManager = FileManager.default

    struct RecorderEntry: Codable {
        let timestamp: TimeInterval
        let frequency: Float?
        let confidence: Float?
        let midiNote: Int?
        let referenceHz: Double?
        let cents: Double?
    }

    func startRecording() {
        entries = []
        isRecording = true
        AppLogger.pitch.info("Pitch recording started")
    }

    func record(
        detected: PitchResult?,
        reference: ReferencePitchFrame?,
        playbackTime: Double
    ) {
        guard isRecording else { return }

        let cents: Double? = {
            guard let det = detected,
                  let ref = reference,
                  ref.isVoiced,
                  let refHz = ref.frequency else { return nil }
            return Double(NoteMapper.centsBetween(
                detected: det.frequency,
                reference: Float(refHz)
            ))
        }()

        entries.append(RecorderEntry(
            timestamp: playbackTime,
            frequency: detected?.frequency,
            confidence: detected?.confidence,
            midiNote: detected?.midiNote,
            referenceHz: reference.flatMap(\.frequency),
            cents: cents
        ))
    }

    func stopRecording() {
        isRecording = false
        let count = entries.count
        AppLogger.pitch.info("Pitch recording stopped: \(count) entries")
    }

    /// Export recorded data to a JSON file in the Documents directory.
    func export() -> URL? {
        guard !entries.isEmpty else { return nil }

        let docs = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        let filename = "pitch_recording_\(Int(Date().timeIntervalSince1970)).json"
        let url = docs.appendingPathComponent(filename)

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(entries)
            try data.write(to: url)
            AppLogger.pitch.info("Exported pitch recording to \(url.lastPathComponent)")
            return url
        } catch {
            AppLogger.pitch.error("Export failed: \(error.localizedDescription)")
            return nil
        }
    }
}
#endif
