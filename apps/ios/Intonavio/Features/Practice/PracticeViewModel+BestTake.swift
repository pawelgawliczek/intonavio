import AVFoundation

// MARK: - Best Take Recording

extension PracticeViewModel {
    /// Whether a best take recording exists for this song.
    var hasBestTake: Bool {
        BestTakeStorage.exists(for: songId)
    }

    /// URL to a backing track stem file for best take playback/export.
    /// Prefers the instrumental stem, falls back to the full mix.
    var instrumentalStemURL: URL? {
        let preferred: [StemType] = [.instrumental, .full]
        let caches = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )[0]
        let stemDir = caches
            .appendingPathComponent("stems", isDirectory: true)
            .appendingPathComponent(songId, isDirectory: true)

        for type in preferred {
            guard stems.contains(where: { $0.type == type }) else { continue }
            let url = stemDir.appendingPathComponent("\(type.rawValue.lowercased()).mp3")
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    /// Start recording mic audio to a temp file for best take.
    /// Stays running across pause/resume to keep the timeline aligned
    /// with the instrumental — ambient noise during pauses is harmless.
    func startBestTakeRecording() {
        guard !isSongScoreInvalidated else { return }
        guard streamingRecorder == nil else { return }

        let recorder = StreamingRecorder()
        let tempURL = BestTakeStorage.tempURL()
        let format = audioEngine.inputFormat

        do {
            try recorder.startStreaming(
                router: audioEngine.inputTapRouter,
                to: tempURL,
                format: format
            )
            streamingRecorder = recorder
            bestTakeStartTime = currentTime
            bestTakeTempURL = tempURL
            AppLogger.recording.info(
                "Best take recording started at videoTime=\(self.currentTime)"
            )
        } catch {
            AppLogger.recording.error(
                "Failed to start best take recording: \(error.localizedDescription)"
            )
        }
    }

    /// Finalize the best take: promote if new best, otherwise discard.
    func finalizeBestTake(isNewBest: Bool) {
        guard let recorder = streamingRecorder else { return }
        recorder.stopStreaming()

        guard let tempURL = bestTakeTempURL else {
            streamingRecorder = nil
            return
        }

        if isNewBest {
            let session = AVAudioSession.sharedInstance()
            let ioLatency = session.inputLatency + session.outputLatency

            // Auto-detect sync offset by comparing first phrase time
            // with first vocal onset in the recording.
            let syncOffset = detectSyncOffset(
                vocalURL: tempURL,
                ioLatency: ioLatency
            )

            AppLogger.recording.info(
                "Best take: ioLatency=\(ioLatency) syncOffset=\(syncOffset)"
            )
            let metadata = BestTakeMetadata(
                startOffset: bestTakeStartTime,
                score: scoringEngine?.overallScore ?? 0,
                date: Date(),
                ioLatency: ioLatency,
                syncOffset: syncOffset
            )
            do {
                try BestTakeStorage.promote(
                    tempURL: tempURL,
                    songId: songId,
                    metadata: metadata
                )
            } catch {
                AppLogger.recording.error(
                    "Failed to promote best take: \(error.localizedDescription)"
                )
            }
        } else {
            try? FileManager.default.removeItem(at: tempURL)
        }

        streamingRecorder = nil
        bestTakeTempURL = nil
    }

    /// Detect sync offset by finding the first vocal onset in the recording
    /// and comparing it to when the first phrase should start.
    private func detectSyncOffset(
        vocalURL: URL,
        ioLatency: TimeInterval
    ) -> TimeInterval {
        guard let firstPhrase = referenceStore.phrases.first else { return 0 }

        // Expected onset: first phrase time relative to recording start
        let expectedOnset = firstPhrase.startTime - bestTakeStartTime

        // Find actual onset in the vocal recording
        guard let actualOnset = findFirstVocalOnset(
            url: vocalURL,
            searchStart: max(0, expectedOnset - 0.5),
            searchEnd: expectedOnset + 3.0
        ) else { return 0 }

        let offset = actualOnset - expectedOnset
        AppLogger.recording.info(
            "Sync detect: expected=\(expectedOnset) actual=\(actualOnset) offset=\(offset)"
        )

        // Only apply if offset is positive (vocal late) and reasonable (< 3s)
        return offset > 0.02 && offset < 3.0 ? offset : 0
    }

    /// Scan a CAF file for the first frame where RMS exceeds the threshold.
    /// Returns the time in seconds, or nil if not found.
    private func findFirstVocalOnset(
        url: URL,
        searchStart: TimeInterval,
        searchEnd: TimeInterval
    ) -> TimeInterval? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }

        let sampleRate = file.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(searchStart * sampleRate)
        let endFrame = min(
            AVAudioFramePosition(searchEnd * sampleRate),
            file.length
        )
        guard endFrame > startFrame else { return nil }

        let chunkSize: AVAudioFrameCount = 4096
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: chunkSize
        ) else { return nil }

        file.framePosition = startFrame
        let rmsThreshold: Float = 0.02
        var currentFrame = startFrame

        while currentFrame < endFrame {
            let framesToRead = AVAudioFrameCount(
                min(Int64(chunkSize), endFrame - currentFrame)
            )
            do {
                try file.read(into: buffer, frameCount: framesToRead)
            } catch {
                break
            }

            guard let channelData = buffer.floatChannelData?[0] else { break }
            let frameCount = Int(buffer.frameLength)

            // Check RMS in small windows (10ms)
            let windowSize = max(1, Int(sampleRate * 0.01))
            for windowStart in stride(from: 0, to: frameCount, by: windowSize) {
                let windowEnd = min(windowStart + windowSize, frameCount)
                var sumSquares: Float = 0
                for i in windowStart..<windowEnd {
                    sumSquares += channelData[i] * channelData[i]
                }
                let rms = sqrtf(sumSquares / Float(windowEnd - windowStart))
                if rms > rmsThreshold {
                    let onsetFrame = currentFrame + Int64(windowStart)
                    return Double(onsetFrame) / sampleRate
                }
            }

            currentFrame += Int64(buffer.frameLength)
        }

        return nil
    }

    /// Stop recording and discard (called on seek/loop invalidation).
    func invalidateBestTakeRecording() {
        streamingRecorder?.discard()
        streamingRecorder = nil
        bestTakeTempURL = nil
    }

    /// Clean up any temp recording file on view disappear.
    func cleanupBestTakeTemp() {
        streamingRecorder?.discard()
        streamingRecorder = nil
        bestTakeTempURL = nil
    }
}
