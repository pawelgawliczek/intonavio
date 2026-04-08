import Foundation

// MARK: - Pitch Edit Script Integration

extension PracticeViewModel {
    /// Decide between plain base load and script-merged load, then hand off
    /// the result to the reference store. Called from `loadPitchDataIfAvailable`.
    func applyPitchDataWithScript(_ baseData: ReferencePitchData) {
        let script = PitchEditScriptStore.load(songId: songId)
        hasCustomScript = script != nil

        guard let script else {
            referenceStore.load(from: baseData)
            isPitchReady = true
            layoutMode = .lyrics
            AppLogger.pitch.info("Reference pitch loaded for practice")
            return
        }

        if let cached = MergedFrameCache.load(songId: songId, updatedAt: script.updatedAt) {
            referenceStore.load(from: cached)
            isPitchReady = true
            layoutMode = .lyrics
            AppLogger.pitch.info("Reference pitch loaded from merged cache")
            return
        }

        // Load base synchronously so the UI isn't blank while the merge runs.
        referenceStore.load(from: baseData)
        isPitchReady = true
        layoutMode = .lyrics

        Task { [weak self] in
            await self?.mergeAndApplyScript(baseData: baseData, script: script)
        }
    }

    @MainActor
    private func mergeAndApplyScript(
        baseData: ReferencePitchData,
        script: PitchEditScript
    ) async {
        let neededSources = collectNeededVariantSources(script: script)
        let otherVariants = await loadOtherVariants(sources: neededSources)

        let mergedFrames = PitchEditApplier.apply(
            base: baseData.frames,
            hopDuration: baseData.hopDuration,
            otherVariants: otherVariants,
            script: script
        )
        let mergedData = ReferencePitchData(
            songId: baseData.songId,
            sampleRate: baseData.sampleRate,
            hopSize: baseData.hopSize,
            frameCount: mergedFrames.count,
            hopDuration: baseData.hopDuration,
            frames: mergedFrames,
            phrases: baseData.phrases
        )

        MergedFrameCache.invalidate(songId: songId, keepUpdatedAt: script.updatedAt)
        MergedFrameCache.save(songId: songId, updatedAt: script.updatedAt, data: mergedData)
        referenceStore.load(from: mergedData)
        AppLogger.pitch.info("Reference pitch merged with edit script")
    }

    private func collectNeededVariantSources(script: PitchEditScript) -> Set<StemSource> {
        let activeSource = variants.first(where: { $0.id == activeVariantId })?.source
        var sources: Set<StemSource> = []
        for op in script.operations {
            if case .useVariant(_, _, let source) = op {
                if source != activeSource { sources.insert(source) }
            }
        }
        return sources
    }

    private func loadOtherVariants(
        sources: Set<StemSource>
    ) async -> [StemSource: [ReferencePitchFrame]] {
        guard !sources.isEmpty else { return [:] }
        var result: [StemSource: [ReferencePitchFrame]] = [:]
        let apiClient = APIClient()
        for source in sources {
            guard let variant = variants.first(
                where: { $0.source == source && $0.status == .ready }
            ) else {
                AppLogger.pitch.info(
                    "Edit script references unavailable variant \(source.rawValue)"
                )
                continue
            }
            do {
                let url = try await PitchDataDownloader.localURL(
                    songId: songId,
                    variantId: variant.id,
                    apiClient: apiClient
                )
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode(ReferencePitchData.self, from: data)
                result[source] = decoded.frames
            } catch {
                AppLogger.pitch.error(
                    "Failed to load variant \(source.rawValue) for merge: \(error.localizedDescription)"
                )
            }
        }
        return result
    }
}
