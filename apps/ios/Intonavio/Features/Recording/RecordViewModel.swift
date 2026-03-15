import AVFoundation
import SwiftData

/// Manages the recording lifecycle: capture audio, analyze pitch,
/// save as a Recording with detected notes.
@Observable
final class RecordViewModel {
    enum State {
        case idle
        case recording
        case analyzing
        case review(notes: [DetectedNote])
        case error(String)
    }

    var state: State = .idle
    var recordingName = ""
    private(set) var isImportMode = false

    var currentDuration: TimeInterval { recorder.currentDuration }
    var audioLevel: Float { recorder.audioLevel }

    private let audioEngine = AudioEngine()
    private let recorder: AudioRecorder
    private var analysisResult: RecordingAnalyzer.Result?
    private var importedSamples: [Float]?
    private var importedSampleRate: Double = 0

    init() {
        self.recorder = AudioRecorder(engine: audioEngine)
    }

    deinit {
        recorder.stopRecording()
        audioEngine.shutdown()
    }

    // MARK: - Actions

    func startRecording() {
        do {
            try recorder.startRecording()
            state = .recording
        } catch {
            AppLogger.audio.error("Recording failed: \(error.localizedDescription)")
            state = .error(error.localizedDescription)
        }
    }

    func stopRecording() {
        recorder.stopRecording()
        state = .analyzing
        analyzeRecording()
    }

    func importAudioFile(url: URL) {
        isImportMode = true
        state = .analyzing

        Task { @MainActor in
            do {
                let (samples, sampleRate) = try readAudioFile(url: url)
                let result = try RecordingAnalyzer.analyze(
                    samples: samples, sampleRate: sampleRate
                )
                self.importedSamples = samples
                self.importedSampleRate = sampleRate
                self.analysisResult = result
                self.recordingName = defaultName(for: result.notes)
                self.state = .review(notes: result.notes)
                AppLogger.recording.info(
                    "Import analysis: \(result.notes.count) notes from \(url.lastPathComponent)"
                )
            } catch {
                AppLogger.recording.error(
                    "Import failed: \(error.localizedDescription)"
                )
                self.state = .error(error.localizedDescription)
            }
        }
    }

    func reRecord() {
        analysisResult = nil
        importedSamples = nil
        recordingName = ""
        isImportMode = false
        state = .idle
    }

    func save(modelContext: ModelContext) -> Recording? {
        guard let result = analysisResult else { return nil }

        let id = UUID()
        let dirName = "recordings/\(id.uuidString)"
        let docsURL = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        )[0]
        let dirURL = docsURL.appendingPathComponent(dirName)

        do {
            try FileManager.default.createDirectory(
                at: dirURL, withIntermediateDirectories: true
            )
            if let importedSamples {
                try writeCAF(
                    samples: importedSamples,
                    sampleRate: importedSampleRate,
                    directory: dirURL
                )
            } else {
                _ = try recorder.writeToFile(directory: dirURL)
            }
        } catch {
            AppLogger.audio.error("Save audio failed: \(error.localizedDescription)")
            state = .error("Failed to save audio file")
            return nil
        }

        let name = recordingName.isEmpty
            ? defaultName(for: result.notes)
            : recordingName

        let pitchFramesData: Data
        let detectedNotesData: Data
        do {
            pitchFramesData = try JSONEncoder().encode(result.pitchData.frames)
            detectedNotesData = try JSONEncoder().encode(result.notes)
        } catch {
            AppLogger.audio.error("Encode failed: \(error.localizedDescription)")
            state = .error("Failed to encode pitch data")
            return nil
        }

        let midiValues = result.notes.map(\.midi)

        let duration = importedSamples != nil
            ? Double(importedSamples!.count) / importedSampleRate
            : recorder.currentDuration

        let recording = Recording(
            name: name,
            duration: duration,
            audioFileName: "\(dirName)/audio.caf",
            pitchFrames: pitchFramesData,
            detectedNotes: detectedNotesData,
            noteCount: result.notes.count,
            lowestMidi: midiValues.min() ?? 60,
            highestMidi: midiValues.max() ?? 72
        )
        recording.id = id

        modelContext.insert(recording)
        AppLogger.audio.info("Saved recording '\(name)' with \(result.notes.count) notes")
        return recording
    }
}

// MARK: - Private

private extension RecordViewModel {
    func analyzeRecording() {
        let samples = Array(recorder.recordedSamples)
        let sampleRate = recorder.recordedSampleRate

        Task { @MainActor in
            do {
                let result = try RecordingAnalyzer.analyze(
                    samples: samples,
                    sampleRate: sampleRate
                )
                self.analysisResult = result
                self.recordingName = defaultName(for: result.notes)
                self.state = .review(notes: result.notes)
                AppLogger.audio.info(
                    "Analysis complete: \(result.notes.count) notes detected"
                )
            } catch {
                AppLogger.audio.error(
                    "Analysis failed: \(error.localizedDescription)"
                )
                self.state = .error(error.localizedDescription)
            }
        }
    }

    func defaultName(for notes: [DetectedNote]) -> String {
        guard let first = notes.first else { return "Recording" }
        if notes.count == 1 { return first.name }
        return "\(first.name) + \(notes.count - 1) more"
    }

    func readAudioFile(url: URL) throws -> ([Float], Double) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        let audioFile = try AVAudioFile(forReading: url)
        let fileFormat = audioFile.fileFormat
        let sampleRate = fileFormat.sampleRate

        let processingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: fileFormat.channelCount,
            interleaved: false
        )!

        let frameCount = AVAudioFrameCount(audioFile.length)
        guard let pcmBuffer = AVAudioPCMBuffer(
            pcmFormat: processingFormat, frameCapacity: frameCount
        ) else {
            throw RecordingError.emptyBuffer
        }

        try audioFile.read(into: pcmBuffer)

        guard let channelData = pcmBuffer.floatChannelData else {
            throw RecordingError.emptyBuffer
        }

        let sampleCount = Int(pcmBuffer.frameLength)
        let channels = Int(fileFormat.channelCount)

        let samples: [Float]
        if channels > 1 {
            samples = (0..<sampleCount).map { i in
                var sum: Float = 0
                for ch in 0..<channels {
                    sum += channelData[ch][i]
                }
                return sum / Float(channels)
            }
        } else {
            samples = Array(
                UnsafeBufferPointer(start: channelData[0], count: sampleCount)
            )
        }

        return (samples, sampleRate)
    }

    func writeCAF(
        samples: [Float], sampleRate: Double, directory: URL
    ) throws {
        let fileURL = directory.appendingPathComponent("audio.caf")
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )!
        let file = try AVAudioFile(
            forWriting: fileURL,
            settings: format.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        let count = samples.count
        let pcmBuffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(count)
        )!
        pcmBuffer.frameLength = AVAudioFrameCount(count)
        samples.withUnsafeBufferPointer { src in
            pcmBuffer.floatChannelData![0].update(
                from: src.baseAddress!, count: count
            )
        }
        try file.write(from: pcmBuffer)
    }
}
