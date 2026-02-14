import Foundation

// MARK: - Audio Mode & Stem Management

extension PracticeViewModel {
    /// Switch audio source: original (FULL stem or YouTube), vocals only, or instrumental.
    /// Uses pause-switch-resume to prevent sync issues during transition.
    @MainActor
    func setAudioMode(_ mode: AudioMode) {
        guard mode != audioMode else { return }

        guard isStemsReady else {
            downloadStemsAndSwitch(to: mode)
            return
        }

        let wasPlaying = loopState == .playing || loopState == .looping
        let resumeTime = currentTime

        if wasPlaying {
            sync?.stop()
            stemPlayer.stop()
        }

        // Mute YouTube once stems are ready (for songs with FULL stem)
        if hasFullStem && !isMuted {
            controller.mute()
            isMuted = true
        }

        // Legacy fallback: songs without FULL stem use YouTube for original mode
        if !hasFullStem {
            if mode == .original {
                switchToOriginal()
                audioMode = mode
                return
            }
            if audioMode == .original && !isMuted {
                controller.mute()
                isMuted = true
            }
        }

        audioMode = mode
        stemPlayer.applyMode(mode)
        stemPlayer.rate = Float(playbackRate)

        if wasPlaying {
            stemPlayer.play(from: resumeTime)
            sync?.start()
        }
    }

    /// Pre-download stems in the background so mode switching is instant.
    func preloadStems() {
        guard !stems.isEmpty, !isStemsReady, !isDownloadingStems else { return }
        Task { @MainActor in
            await performStemDownload()
        }
    }
}

// MARK: - Private

private extension PracticeViewModel {
    @MainActor
    func switchToOriginal() {
        sync?.stop()
        stemPlayer.stop()
        controller.unmute()
        isMuted = false
    }

    @MainActor
    func downloadStemsAndSwitch(to mode: AudioMode) {
        Task { @MainActor in
            await performStemDownload()
            guard isStemsReady else { return }
            setAudioMode(mode)
        }
    }

    @MainActor
    func performStemDownload() async {
        guard !isDownloadingStems else { return }
        isDownloadingStems = true

        do {
            var stemFiles: [(type: StemType, url: URL)] = []
            for stem in stems {
                let url = try await stemDownloader.localURL(
                    songId: songId,
                    stemId: stem.id,
                    stemType: stem.type
                )
                stemFiles.append((type: stem.type, url: url))
            }

            try stemPlayer.setup(stems: stemFiles)
            isStemsReady = true
            let count = stemFiles.count
            AppLogger.audio.info("Stems ready: \(count) loaded")

            // Auto-mute YouTube and activate FULL stem when available
            if hasFullStem {
                controller.mute()
                isMuted = true
                stemPlayer.applyMode(audioMode)
            }
        } catch {
            AppLogger.audio.error(
                "Stem download failed: \(error.localizedDescription)"
            )
        }

        isDownloadingStems = false
    }
}

// MARK: - Session Auto-Save

extension PracticeViewModel {
    func saveSessionIfNeeded() {
        guard !sessionSaved,
              playbackDuration >= Self.minimumPlaybackForSave else {
            return
        }
        sessionSaved = true

        let score = scoringEngine?.finalScore ?? 0
        let log = scoringEngine?.pitchLog ?? []

        sessionsViewModel?.saveSession(
            CreateSessionRequest(
                songId: songId,
                duration: Int(playbackDuration),
                loopStart: markerA,
                loopEnd: markerB,
                speed: playbackRate,
                overallScore: score,
                pitchLog: log
            )
        )
        let sid = songId
        AppLogger.sessions.info("Auto-saved session for song \(sid)")
    }
}
