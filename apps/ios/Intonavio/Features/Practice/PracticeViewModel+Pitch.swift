import Foundation

// MARK: - Pitch Detection & Scoring Integration

extension PracticeViewModel {
    /// Start pitch detection and scoring when playback begins.
    func startPitchDetection() {
        guard isPitchReady else { return }

        if pitchDetector == nil {
            pitchDetector = PitchDetector(engine: audioEngine)
        }

        guard let detector = pitchDetector else { return }

        do {
            try detector.start()
            detector.onPitchDetected = { [weak self] result in
                self?.handleDetectedPitch(result)
            }
        } catch {
            AppLogger.pitch.error(
                "Failed to start pitch detection: \(error.localizedDescription)"
            )
        }
    }

    /// Stop pitch detection.
    func stopPitchDetection() {
        pitchDetector?.stop()
        pitchDetector?.onPitchDetected = nil
    }

    /// Load reference pitch data if available and cached.
    func loadPitchDataIfAvailable() {
        guard PitchDataDownloader.isCached(songId: songId, variantId: activeVariantId) else {
            isPitchReady = false
            return
        }

        let url = PitchDataDownloader.cacheURL(for: songId, variantId: activeVariantId)

        do {
            try referenceStore.load(from: url)
            isPitchReady = true
            layoutMode = .lyrics
            AppLogger.pitch.info("Reference pitch loaded for practice")
        } catch {
            isPitchReady = false
            AppLogger.pitch.error(
                "Failed to load pitch data: \(error.localizedDescription)"
            )
        }
    }

    /// Download pitch data if the song has it but it's not yet cached.
    func downloadPitchDataIfNeeded(
        hasPitchData: Bool,
        apiClient: any APIClientProtocol
    ) {
        guard hasPitchData,
              !PitchDataDownloader.isCached(songId: songId, variantId: activeVariantId) else {
            return
        }

        isPitchLoading = true
        let variantId = activeVariantId
        Task {
            do {
                _ = try await PitchDataDownloader.localURL(
                    songId: songId,
                    variantId: variantId,
                    apiClient: apiClient
                )
                await MainActor.run {
                    isPitchLoading = false
                    loadPitchDataIfAvailable()
                }
            } catch {
                await MainActor.run { isPitchLoading = false }
                AppLogger.pitch.error(
                    "Failed to download pitch data: \(error.localizedDescription)"
                )
            }
        }
    }

    /// Set the transpose offset for reference pitch (visual + scoring).
    /// Persists the value per song so it's restored on next practice.
    func setTranspose(_ semitones: Int) {
        transposeSemitones = semitones
        scoringEngine?.transposeSemitones = semitones
        UserDefaults.standard.set(semitones, forKey: "songTranspose_\(songId)")
    }

    /// Load any previously saved transpose setting for this song.
    func loadSavedTranspose() {
        let key = "songTranspose_\(songId)"
        let saved = UserDefaults.standard.integer(forKey: key)
        guard saved != 0 else { return }
        transposeSemitones = saved
        scoringEngine?.transposeSemitones = saved
    }

    /// Handle each detected pitch result.
    func handleDetectedPitch(_ result: PitchResult) {
        guard !isWaitingForLoopSeek else { return }

        let midi = NoteMapper.frequencyToMidi(result.frequency)
        let now = result.timestamp

        // MIDI jump filter — reject points that jump >12 semitones within 50ms
        if lastDetectionTimestamp > 0 {
            let timeDelta = now - lastDetectionTimestamp
            let midiDelta = abs(midi - lastDetectedMidi)
            if timeDelta < PitchConstants.jumpTimeWindow,
               midiDelta > PitchConstants.maxMidiJump {
                return
            }
        }

        lastDetectedMidi = midi
        lastDetectionTimestamp = now

        scoringEngine?.evaluate(detected: result, playbackTime: currentTime)

        let rawRefHz = referenceStore.frame(at: currentTime)?.frequency
            ?? Double(result.frequency)
        let adjustedRefHz = rawRefHz * pow(2.0, Double(transposeSemitones) / 12.0)
        let cents = NoteMapper.centsBetween(
            detected: result.frequency,
            reference: Float(adjustedRefHz)
        )
        let accuracy = PitchAccuracy.classify(cents: cents)

        let point = DetectedPitchPoint(
            time: currentTime,
            midi: midi,
            accuracy: accuracy,
            cents: cents
        )
        detectedPoints.append(point)

        // Keep buffer at reasonable size (last 30 seconds at ~172/sec ≈ 5160 points)
        if detectedPoints.count > 6000 {
            detectedPoints.removeFirst(1000)
        }
    }
}

// MARK: - Variant Switching

extension PracticeViewModel {
    /// Switch the practice session to a different ready variant of the same song.
    /// Reloads pitch reference data and stem audio for the new variant.
    @MainActor
    func switchToVariant(
        _ variant: SongVariant,
        apiClient: any APIClientProtocol
    ) {
        guard variant.id != activeVariantId else { return }
        guard variant.status == .ready else { return }

        isSwitchingVariant = true
        pause()

        Task { @MainActor in
            do {
                let updated = try await apiClient.setActiveVariant(
                    songId: songId,
                    variantId: variant.id
                )
                applyUpdatedSong(updated)
            } catch {
                AppLogger.library.error(
                    "Failed to switch variant: \(error.localizedDescription)"
                )
            }
            isSwitchingVariant = false
        }
    }

    @MainActor
    func applyUpdatedSong(_ song: SongResponse) {
        variants = song.variants
        activeVariantId = song.activeVariantId
        stems = song.stems

        isPitchReady = false
        isStemsReady = false
        stemPlayer.teardown()
        detectedPoints.removeAll()

        loadPitchDataIfAvailable()
        if !isPitchReady, song.pitchData != nil {
            downloadPitchDataIfNeeded(
                hasPitchData: true,
                apiClient: APIClient()
            )
        }
        preloadStems()
    }
}

