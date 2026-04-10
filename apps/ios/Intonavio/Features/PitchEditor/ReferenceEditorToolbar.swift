import SwiftUI

/// Bottom toolbar of range-based ops for the reference editor.
struct ReferenceEditorToolbar: View {
    @Bindable var viewModel: ReferenceEditorViewModel
    @State private var isShowingDespike = false
    @State private var despikeMaxJump: Double = 4
    @State private var isShowingResetConfirm = false

    private var baseSource: StemSource? {
        let others = Set(viewModel.availableOtherSources)
        return StemSource.allCases.first { !others.contains($0) }
    }

    var body: some View {
        VStack(spacing: 8) {
            Picker("Tool", selection: $viewModel.gesture) {
                Text("Range").tag(EditorGesture.range)
                Text("Draw").tag(EditorGesture.draw)
            }
            .pickerStyle(.segmented)
            if viewModel.gesture == .draw {
                drawControls
            }
            opGrid
            if viewModel.availableOtherSources.isEmpty {
                Text("Process the alternate variant to swap sources for a range.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color.intonavioSurface)
        .confirmationDialog(
            "Clear all edits?",
            isPresented: $isShowingResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) { viewModel.resetAll() }
        } message: {
            Text("Removes every edit in this session. You can undo this.")
        }
        .sheet(isPresented: $isShowingDespike) { despikeSheet }
    }

    // MARK: - Op Grid

    private var opGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)
        return LazyVGrid(columns: columns, spacing: 6) {
            variantCell(.studio)
            variantCell(.draft)
            opCell("Despike", icon: "waveform.path") { isShowingDespike = true }
            opCell("Mute", icon: "speaker.slash") {
                addRangeOp { range in .mute(id: UUID(), range: range) }
            }
            opCell("Fill", icon: "line.diagonal") {
                addRangeOp { range in .fillGaps(id: UUID(), range: range) }
            }
            opCell("Sing", icon: "mic", tint: viewModel.isRecording ? .red : nil) {
                viewModel.startSinging()
            }
            .disabled(viewModel.isRecording)
            opCell("+1 st", icon: "arrow.up") {
                addRangeOp { range in .shiftSemitones(id: UUID(), range: range, semitones: 1) }
            }
            opCell("-1 st", icon: "arrow.down") {
                addRangeOp { range in .shiftSemitones(id: UUID(), range: range, semitones: -1) }
            }
            Button(role: .destructive) {
                isShowingResetConfirm = true
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "trash")
                        .font(.body)
                    Text("Reset")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity, minHeight: 40)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.operations.isEmpty)
        }
    }

    // MARK: - Cells

    private func opCell(
        _ title: String,
        icon: String,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.body)
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity, minHeight: 40)
        }
        .buttonStyle(.bordered)
        .tint(tint)
        .disabled(!viewModel.hasRange)
    }

    private func variantCell(_ source: StemSource) -> some View {
        let isBase = source == baseSource
        let loaded = viewModel.availableOtherSources.contains(source)
        let disabled = isBase || !loaded || !viewModel.hasRange
        return Button {
            addRangeOp { range in .useVariant(id: UUID(), range: range, source: source) }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.body)
                Text(source.displayName)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity, minHeight: 40)
        }
        .buttonStyle(.borderedProminent)
        .disabled(disabled)
    }

    // MARK: - Draw Controls

    private var drawControls: some View {
        VStack(spacing: 6) {
            Picker("Mode", selection: $viewModel.drawMode) {
                Text("Replace").tag(DrawMode.replace)
                Text("Additive").tag(DrawMode.additive)
            }
            .pickerStyle(.segmented)
            HStack {
                Toggle("Snap", isOn: $viewModel.snapToSemitone)
                    .font(.caption)
                Toggle("Smooth", isOn: $viewModel.smoothStroke)
                    .font(.caption)
            }
            .toggleStyle(.switch)
            if viewModel.drawMode == .additive {
                Text("Additive draw only fills unvoiced gaps.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Helpers

    private func addRangeOp(_ make: (TimeRange) -> PitchEditOp) {
        guard let range = viewModel.currentRange else { return }
        viewModel.addOperation(make(range))
    }

    private var despikeSheet: some View {
        NavigationStack {
            Form {
                Section("Max jump (semitones)") {
                    Slider(value: $despikeMaxJump, in: 1...12, step: 0.5)
                    Text("\(despikeMaxJump, specifier: "%.1f") st")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Despike")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isShowingDespike = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        addRangeOp { range in
                            .despike(
                                id: UUID(),
                                range: range,
                                maxJumpSemitones: despikeMaxJump
                            )
                        }
                        isShowingDespike = false
                    }
                    .disabled(!viewModel.hasRange)
                }
            }
        }
        .presentationDetents([.height(220)])
    }
}
