import Accelerate
import Foundation

/// Runs offline YIN analysis over a recorded PCM buffer and segments
/// the result into discrete notes. Produces ReferencePitchData compatible
/// with the existing piano roll and scoring pipeline.
enum RecordingAnalyzer {
    struct Result: Sendable {
        let pitchData: ReferencePitchData
        let notes: [DetectedNote]
    }

    /// Analyze a recorded buffer and return pitch frames + detected notes.
    static func analyze(
        samples: some Collection<Float>,
        sampleRate: Double
    ) throws -> Result {
        let floatRate = Float(sampleRate)
        let hopSize = PitchConstants.hopSize
        let windowSize = PitchConstants.analysisSize
        let hopDuration = Double(hopSize) / sampleRate
        let sampleArray = Array(samples)
        let totalSamples = sampleArray.count

        guard totalSamples >= windowSize else {
            throw RecordingError.emptyBuffer
        }

        let detector = YINDetector(
            sampleRate: floatRate,
            threshold: PitchConstants.yinThreshold,
            minLag: Int(floatRate / PitchConstants.maxFrequency),
            maxLag: Int(floatRate / PitchConstants.minFrequency)
        )

        var frames: [ReferencePitchFrame] = []
        var offset = 0

        while offset + windowSize <= totalSamples {
            let time = Double(offset) / sampleRate
            let frame = analyzeWindow(
                sampleArray, offset: offset, size: windowSize,
                detector: detector, time: time
            )
            frames.append(frame)
            offset += hopSize
        }

        let notes = segmentNotes(frames: frames, hopDuration: hopDuration)

        guard !notes.isEmpty else {
            throw RecordingError.analysisFailed
        }

        let pitchData = ReferencePitchData(
            songId: nil,
            sampleRate: Int(sampleRate),
            hopSize: hopSize,
            frameCount: frames.count,
            hopDuration: hopDuration,
            frames: frames,
            phrases: []
        )

        return Result(pitchData: pitchData, notes: notes)
    }
}

// MARK: - Window Analysis

private extension RecordingAnalyzer {
    static func analyzeWindow(
        _ samples: [Float], offset: Int, size: Int,
        detector: YINDetector, time: Double
    ) -> ReferencePitchFrame {
        var rms: Float = 0
        samples.withUnsafeBufferPointer { ptr in
            vDSP_rmsqv(
                ptr.baseAddress! + offset, 1,
                &rms, vDSP_Length(size)
            )
        }

        guard rms >= PitchConstants.rmsNoiseFloor else {
            return unvoicedFrame(time: time, rms: rms)
        }

        let detection = samples.withUnsafeBufferPointer { ptr -> (Float, Float)? in
            guard let base = ptr.baseAddress else { return nil }
            return detector.detect(base + offset, count: size)
        }

        guard let (frequency, confidence) = detection,
              confidence >= PitchConstants.confidenceThreshold else {
            return unvoicedFrame(time: time, rms: rms)
        }

        let midi = Double(NoteMapper.frequencyToMidi(frequency))

        return ReferencePitchFrame(
            time: time,
            frequency: Double(frequency),
            isVoiced: true,
            midiNote: midi,
            rms: Double(rms)
        )
    }

    static func unvoicedFrame(time: Double, rms: Float) -> ReferencePitchFrame {
        ReferencePitchFrame(
            time: time, frequency: nil, isVoiced: false,
            midiNote: nil, rms: Double(rms)
        )
    }
}

// MARK: - Note Segmentation

private extension RecordingAnalyzer {
    static func segmentNotes(
        frames: [ReferencePitchFrame],
        hopDuration: Double
    ) -> [DetectedNote] {
        var notes: [DetectedNote] = []
        var segmentStart: Int?
        var segmentFrequencies: [Float] = []
        var segmentConfidences: [Float] = []
        var currentMidi: Int?
        var silenceCount = 0
        let silenceThreshold = Int(0.1 / hopDuration) // 100ms

        for (index, frame) in frames.enumerated() {
            guard frame.isVoiced, let hz = frame.frequency else {
                silenceCount += 1
                if silenceCount >= silenceThreshold {
                    if let start = segmentStart {
                        appendNote(
                            &notes, start: start, end: index - silenceCount,
                            frequencies: segmentFrequencies,
                            confidences: segmentConfidences,
                            hopDuration: hopDuration
                        )
                        segmentStart = nil
                        segmentFrequencies = []
                        segmentConfidences = []
                        currentMidi = nil
                    }
                }
                continue
            }

            silenceCount = 0
            let midi = NoteMapper.nearestMidi(Float(hz))

            if let current = currentMidi,
               abs(midi - current) > 1 {
                if let start = segmentStart {
                    appendNote(
                        &notes, start: start, end: index - 1,
                        frequencies: segmentFrequencies,
                        confidences: segmentConfidences,
                        hopDuration: hopDuration
                    )
                }
                segmentStart = index
                segmentFrequencies = [Float(hz)]
                segmentConfidences = [0.9]
                currentMidi = midi
            } else if segmentStart == nil {
                segmentStart = index
                segmentFrequencies = [Float(hz)]
                segmentConfidences = [0.9]
                currentMidi = midi
            } else {
                segmentFrequencies.append(Float(hz))
                segmentConfidences.append(0.9)
            }
        }

        // Flush remaining segment
        if let start = segmentStart {
            appendNote(
                &notes, start: start, end: frames.count - 1,
                frequencies: segmentFrequencies,
                confidences: segmentConfidences,
                hopDuration: hopDuration
            )
        }

        return notes
    }

    static func appendNote(
        _ notes: inout [DetectedNote],
        start: Int, end: Int,
        frequencies: [Float],
        confidences: [Float],
        hopDuration: Double
    ) {
        guard end > start, !frequencies.isEmpty else { return }

        let avgHz = Double(frequencies.reduce(0, +)) / Double(frequencies.count)
        let avgConf = Double(confidences.reduce(0, +)) / Double(confidences.count)
        let midi = NoteMapper.nearestMidi(Float(avgHz))
        let noteInfo = NoteMapper.noteInfo(forMidi: midi)
        let startTime = Double(start) * hopDuration
        let duration = Double(end - start + 1) * hopDuration

        guard duration >= 0.05 else { return } // Skip very short artifacts

        notes.append(DetectedNote(
            midi: midi,
            name: noteInfo.fullName,
            startTime: startTime,
            duration: duration,
            averageHz: avgHz,
            confidence: avgConf
        ))
    }
}
