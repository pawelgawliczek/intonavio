import SwiftUI

/// Full-screen shell for the reference pitch editor (Phase C).
/// Displays a preview piano roll + range sliders + a toolbar of cheap ops.
/// No playback, no draw tool — those arrive in Phase D.
struct ReferenceEditorView: View {
    let songId: String
    let baseVariantId: String
    let songDuration: Double
    let hopDuration: Double
    let baseFrames: [ReferencePitchFrame]
    let variants: [SongVariant]
    let scoreRepository: ScoreRepository?
    var initialTime: Double?
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ReferenceEditorViewModel?
    @State private var isShowingSaveConfirm = false
    @State private var isShowingDiscardConfirm = false
    @State private var isShowingOpList = false

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    content(vm)
                } else {
                    ProgressView().controlSize(.large)
                }
            }
            .navigationTitle("Edit Reference")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .onAppear(perform: makeViewModelIfNeeded)
        .confirmationDialog(
            "Save changes?",
            isPresented: $isShowingSaveConfirm,
            titleVisibility: .visible
        ) {
            Button("Save", role: .destructive) { Task { await performSave() } }
        } message: {
            Text("Saving resets all scores for this song. This cannot be undone.")
        }
        .confirmationDialog(
            "Discard changes?",
            isPresented: $isShowingDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) { dismiss() }
        }
        .sheet(isPresented: $isShowingOpList) {
            if let vm = viewModel { opListSheet(vm) }
        }
    }

    private func makeViewModelIfNeeded() {
        guard viewModel == nil else { return }
        let vm = ReferenceEditorViewModel(
            songId: songId,
            baseVariantId: baseVariantId,
            hopDuration: hopDuration,
            songDuration: songDuration,
            baseFrames: baseFrames,
            variants: variants,
            onSavedScoreWipe: { [scoreRepository] songId in
                scoreRepository?.deleteAllScores(songId: songId)
                BestTakeStorage.delete(for: songId)
            }
        )
        if let t = initialTime {
            vm.setRangeStart(max(0, t - 2))
            vm.setRangeEnd(min(songDuration, t + 2))
            vm.setScrollCenter(t)
        }
        viewModel = vm
    }

    @ViewBuilder
    private func content(_ vm: ReferenceEditorViewModel) -> some View {
        VStack(spacing: 0) {
            playbackBar(vm)
            rangeHeader(vm)
            Divider()
            ReferenceEditorPianoRoll(viewModel: vm)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            ReferenceEditorToolbar(viewModel: vm)
        }
        .onDisappear { vm.stopPlayback() }
    }

    private func playbackBar(_ vm: ReferenceEditorViewModel) -> some View {
        HStack(spacing: 12) {
            Button {
                vm.togglePlay()
            } label: {
                Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
            }
            .buttonStyle(.bordered)
            Text("\(format(vm.playbackTime)) / \(format(songDuration))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Close") {
                if viewModel?.isDirty == true {
                    isShowingDiscardConfirm = true
                } else {
                    dismiss()
                }
            }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                viewModel?.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(viewModel?.canUndo != true)
            Button {
                viewModel?.redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(viewModel?.canRedo != true)
            Button {
                isShowingOpList = true
            } label: {
                Image(systemName: "list.bullet")
            }
            .disabled(viewModel?.operations.isEmpty ?? true)
            Button("Save") {
                isShowingSaveConfirm = true
            }
            .disabled(viewModel?.isDirty != true || viewModel?.isSaving == true)
        }
    }

    private func rangeHeader(_ vm: ReferenceEditorViewModel) -> some View {
        HStack {
            if let start = vm.rangeStart, let end = vm.rangeEnd {
                Text("A: \(format(start))  B: \(format(end))  (dur \(String(format: "%.1f", end - start))s)")
                    .font(.subheadline.monospacedDigit())
            } else {
                Text("Drag to select range · Pinch to zoom")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Full") { vm.selectFullSong() }
                .font(.caption)
            Button("Clear") { vm.clearRange() }
                .font(.caption)
                .disabled(!vm.hasRange)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func opListSheet(_ vm: ReferenceEditorViewModel) -> some View {
        NavigationStack {
            List {
                ForEach(vm.operations) { op in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(op.displayName)
                            .font(.subheadline.weight(.semibold))
                        Text("\(format(op.range.start)) – \(format(op.range.end))")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        vm.removeOperation(id: vm.operations[index].id)
                    }
                }
            }
            .navigationTitle("Edits (\(vm.operations.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isShowingOpList = false }
                }
            }
        }
    }

    private func performSave() async {
        guard let vm = viewModel else { return }
        do {
            try await vm.save()
            onSaved()
            dismiss()
        } catch {
            AppLogger.pitch.error("Editor save failed: \(error.localizedDescription)")
        }
    }

    private func format(_ seconds: Double) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
