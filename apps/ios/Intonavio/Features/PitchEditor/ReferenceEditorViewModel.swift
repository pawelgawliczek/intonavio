import Foundation

/// State container for the reference pitch editor. Owns the operation stack,
/// undo/redo history, and recomputes the preview frames after every mutation.
@Observable
@MainActor
final class ReferenceEditorViewModel {
    let songId: String
    let baseVariantId: String
    let hopDuration: Double
    let songDuration: Double
    let baseFrames: [ReferencePitchFrame]

    var otherVariantFrames: [StemSource: [ReferencePitchFrame]] = [:]
    var availableOtherSources: [StemSource] = []
    var operations: [PitchEditOp]
    var previewFrames: [ReferencePitchFrame] = []

    var undoStack: [[PitchEditOp]] = []
    var redoStack: [[PitchEditOp]] = []

    var rangeStart: Double?
    var rangeEnd: Double?

    var isSaving = false
    var errorMessage: String?

    private let initialOperations: [PitchEditOp]
    private let variants: [SongVariant]
    private let onSavedScoreWipe: (String) -> Void

    init(
        songId: String,
        baseVariantId: String,
        hopDuration: Double,
        songDuration: Double,
        baseFrames: [ReferencePitchFrame],
        variants: [SongVariant],
        onSavedScoreWipe: @escaping (String) -> Void
    ) {
        self.songId = songId
        self.baseVariantId = baseVariantId
        self.hopDuration = hopDuration
        self.songDuration = songDuration
        self.baseFrames = baseFrames
        self.variants = variants
        self.onSavedScoreWipe = onSavedScoreWipe

        let existing = PitchEditScriptStore.load(songId: songId)
        let ops = existing?.operations ?? []
        self.operations = ops
        self.initialOperations = ops
        recomputePreview()
        Task { [weak self] in await self?.loadOtherVariantsInBackground() }
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var isDirty: Bool { operations != initialOperations }
    var hasRange: Bool { rangeStart != nil && rangeEnd != nil }

    var currentRange: TimeRange? {
        guard let start = rangeStart, let end = rangeEnd, end > start else { return nil }
        return TimeRange(start: start, end: end)
    }

    // MARK: - Range

    func setRangeStart(_ value: Double) {
        rangeStart = max(0, min(value, songDuration))
        if let end = rangeEnd, end <= rangeStart ?? 0 {
            rangeEnd = min(songDuration, (rangeStart ?? 0) + hopDuration)
        }
    }

    func setRangeEnd(_ value: Double) {
        rangeEnd = max(0, min(value, songDuration))
        if let start = rangeStart, start >= rangeEnd ?? 0 {
            rangeStart = max(0, (rangeEnd ?? 0) - hopDuration)
        }
    }

    func clearRange() {
        rangeStart = nil
        rangeEnd = nil
    }

    func selectFullSong() {
        rangeStart = 0
        rangeEnd = songDuration
    }

    // MARK: - Ops

    func addOperation(_ op: PitchEditOp) {
        undoStack.append(operations)
        redoStack.removeAll()
        operations.append(op)
        recomputePreview()
    }

    func removeOperation(id: UUID) {
        undoStack.append(operations)
        redoStack.removeAll()
        operations.removeAll { $0.id == id }
        recomputePreview()
    }

    func resetAll() {
        undoStack.append(operations)
        redoStack.removeAll()
        operations.removeAll()
        recomputePreview()
    }

    func undo() {
        guard let prev = undoStack.popLast() else { return }
        redoStack.append(operations)
        operations = prev
        recomputePreview()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(operations)
        operations = next
        recomputePreview()
    }

    // MARK: - Preview

    private func buildScript() -> PitchEditScript {
        PitchEditScript(
            songId: songId,
            baseVariantId: baseVariantId,
            operations: operations
        )
    }

    func recomputePreview() {
        previewFrames = PitchEditApplier.apply(
            base: baseFrames,
            hopDuration: hopDuration,
            otherVariants: otherVariantFrames,
            script: buildScript()
        )
    }

    // MARK: - Save

    func save() async throws {
        isSaving = true
        defer { isSaving = false }
        let script = PitchEditScript(
            songId: songId,
            baseVariantId: baseVariantId,
            operations: operations,
            updatedAt: Date()
        )
        try PitchEditScriptStore.save(script)
        onSavedScoreWipe(songId)
        MergedFrameCache.invalidate(songId: songId)
        AppLogger.pitch.info("Reference edit script saved for \(self.songId)")
    }

    // MARK: - Variant Loading

    private func loadOtherVariantsInBackground() async {
        let apiClient = APIClient()
        let others = variants.filter { $0.id != baseVariantId && $0.status == .ready }
        var loaded: [StemSource: [ReferencePitchFrame]] = [:]
        var available: [StemSource] = []
        for variant in others {
            do {
                let url = try await PitchDataDownloader.localURL(
                    songId: songId,
                    variantId: variant.id,
                    apiClient: apiClient
                )
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode(ReferencePitchData.self, from: data)
                loaded[variant.source] = decoded.frames
                available.append(variant.source)
            } catch {
                AppLogger.pitch.error(
                    "Editor: failed to load variant \(variant.source.rawValue): \(error.localizedDescription)"
                )
            }
        }
        otherVariantFrames = loaded
        availableOtherSources = available
        recomputePreview()
    }
}
