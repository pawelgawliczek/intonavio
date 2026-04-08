import SwiftUI

/// Bottom toolbar of range-based ops for the reference editor.
struct ReferenceEditorToolbar: View {
    @Bindable var viewModel: ReferenceEditorViewModel
    @State private var isShowingDespike = false
    @State private var despikeMaxJump: Double = 4
    @State private var isShowingResetConfirm = false

    private var baseSource: StemSource? {
        // Base variant source is whatever is not in availableOtherSources among the two.
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
            HStack(spacing: 8) {
                variantButton(.studio)
                variantButton(.draft)
                opButton("Despike", systemImage: "waveform.path") {
                    isShowingDespike = true
                }
                opButton("Mute", systemImage: "speaker.slash") {
                    addRangeOp { range in .mute(id: UUID(), range: range) }
                }
            }
            if viewModel.availableOtherSources.isEmpty {
                Text("Process the alternate variant to swap sources for a range.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 8) {
                opButton("+8ve", systemImage: "arrow.up") {
                    addRangeOp { range in
                        .shiftOctave(id: UUID(), range: range, octaves: 1)
                    }
                }
                opButton("-8ve", systemImage: "arrow.down") {
                    addRangeOp { range in
                        .shiftOctave(id: UUID(), range: range, octaves: -1)
                    }
                }
                Button(role: .destructive) {
                    isShowingResetConfirm = true
                } label: {
                    Label("Reset", systemImage: "trash")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.operations.isEmpty)
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

    private func variantButton(_ source: StemSource) -> some View {
        let isBase = source == baseSource
        let loaded = viewModel.availableOtherSources.contains(source)
        let disabled = isBase || !loaded || !viewModel.hasRange
        return Button {
            addRangeOp { range in
                .useVariant(id: UUID(), range: range, source: source)
            }
        } label: {
            Label("Use \(source.displayName)", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(disabled)
    }

    private func opButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(!viewModel.hasRange)
    }

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
