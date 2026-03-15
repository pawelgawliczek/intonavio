import SwiftData
import SwiftUI

struct RecordingPracticeView: View {
    let recording: Recording

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: RecordingPracticeViewModel?
    @State private var showNoteEditor = false
    @State private var scoreSaved = false

    var body: some View {
        Group {
            if let vm = viewModel {
                practiceContent(vm)
            } else {
                ProgressView("Preparing...")
            }
        }
        .navigationTitle(recording.name)
        .navigationBarTitleDisplayMode(.inline)
        .hideTabBarIfNeeded()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNoteEditor = true
                } label: {
                    Image(systemName: "pencil.line")
                }
            }
        }
        .sheet(isPresented: $showNoteEditor) {
            // Reload after edits
            viewModel?.stop()
            viewModel?.restart()
        } content: {
            if let vm = viewModel {
                RecordingNoteEditorView(
                    recording: recording,
                    onLoopNote: { note in
                        vm.setLoop(
                            start: note.startTime,
                            end: note.startTime + note.duration
                        )
                    }
                )
            }
        }
        .onAppear { setupIfNeeded() }
        .onDisappear {
            viewModel?.stop()
            viewModel?.audioEngine.shutdown()
        }
        #if os(macOS)
        .onKeyPress(.space) {
            guard let vm = viewModel else { return .ignored }
            if vm.isPlaying { vm.pause() } else { vm.play() }
            return .handled
        }
        .onKeyPress(.escape) {
            viewModel?.stop()
            dismiss()
            return .handled
        }
        #endif
    }
}

// MARK: - Subviews

private extension RecordingPracticeView {
    func practiceContent(_ vm: RecordingPracticeViewModel) -> some View {
        VStack(spacing: 0) {
            recordingHeader(vm)
            Divider()
            pianoRollSection(vm)
            Divider()
            practiceControls(vm)

            if vm.isComplete {
                completionBanner(vm)
            }
        }
    }

    func recordingHeader(_ vm: RecordingPracticeViewModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(recording.name)
                    .font(.headline)
                Text("\(recording.noteCount) note\(recording.noteCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(Color.intonavioTextSecondary)
            }
            Spacer()

            if vm.isLooping {
                Button {
                    vm.clearLoop()
                } label: {
                    Label("Loop", systemImage: "repeat.1")
                        .font(.caption)
                        .foregroundStyle(Color.intonavioAmber)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }

            Text(String(format: "%.1fs", recording.duration))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Color.intonavioTextSecondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    func pianoRollSection(_ vm: RecordingPracticeViewModel) -> some View {
        let windowStart = vm.currentTime - 4.0
        let windowEnd = vm.currentTime + 4.0
        let frames = vm.referenceStore.frames(from: windowStart, to: windowEnd)

        return PianoRollView(
            mode: Binding(
                get: { vm.visualizationMode },
                set: { vm.visualizationMode = $0 }
            ),
            referenceFrames: frames,
            hopDuration: vm.referenceStore.hopDuration,
            detectedPoints: vm.detectedPoints,
            currentTime: vm.currentTime,
            currentNoteName: vm.currentNoteName,
            centsDeviation: vm.centsDeviation,
            accuracy: vm.currentAccuracy,
            score: vm.score,
            isPitchReady: vm.isPrepared,
            midiMin: vm.referenceStore.midiMin,
            midiMax: vm.referenceStore.midiMax,
            transposeSemitones: vm.transposeSemitones,
            zones: DifficultyLevel.current.zones
        )
        .frame(maxHeight: .infinity)
    }

    func practiceControls(_ vm: RecordingPracticeViewModel) -> some View {
        VStack(spacing: 8) {
            ProgressView(value: vm.currentTime, total: max(vm.duration, 0.01))
                .tint(Color.intonavioAmber)
                .padding(.horizontal)

            HStack(spacing: 20) {
                Button { vm.restart() } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title3)
                }

                Button {
                    if vm.isPlaying { vm.pause() } else { vm.play() }
                } label: {
                    Image(systemName: vm.isPlaying
                        ? "pause.circle.fill"
                        : "play.circle.fill")
                        .font(.largeTitle)
                }
            }
            .padding(.vertical, 4)

            HStack(spacing: 12) {
                transposePicker(vm)
                Spacer()
                speedSelector(vm)
            }
            .padding(.horizontal)

            Picker("Mode", selection: Binding(
                get: { vm.visualizationMode },
                set: { vm.visualizationMode = $0 }
            )) {
                ForEach(VisualizationMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }

    func transposePicker(_ vm: RecordingPracticeViewModel) -> some View {
        let isActive = vm.transposeSemitones != 0
        let buttonLabel = isActive
            ? (vm.transposeSemitones > 0
                ? "+\(vm.transposeSemitones)"
                : "\(vm.transposeSemitones)")
            : "T"

        return Menu {
            ForEach(TransposeInterval.allCases) { interval in
                Button {
                    vm.setTranspose(interval.rawValue)
                } label: {
                    HStack {
                        Text(interval.label)
                        if vm.transposeSemitones == interval.rawValue {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "arrow.up.arrow.down")
                Text(buttonLabel)
                    .font(.caption.monospacedDigit())
            }
            .font(.body)
            .frame(height: 34)
            .padding(.horizontal, 6)
            .foregroundStyle(
                isActive ? Color.intonavioIce : Color.intonavioTextSecondary
            )
            .background(
                isActive
                    ? Color.intonavioIce.opacity(0.15)
                    : Color.intonavioSurface,
                in: RoundedRectangle(cornerRadius: 6)
            )
        }
    }

    func speedSelector(_ vm: RecordingPracticeViewModel) -> some View {
        let speeds: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5]
        return HStack(spacing: 4) {
            ForEach(speeds, id: \.self) { rate in
                Button(rate == 1.0 ? "1x" : String(format: "%.2gx", rate)) {
                    vm.setSpeed(rate)
                }
                .buttonStyle(.bordered)
                .tint(
                    vm.playbackRate == rate
                        ? Color.intonavioIce
                        : Color.intonavioTextSecondary
                )
                .controlSize(.mini)
            }
        }
    }

    func completionBanner(_ vm: RecordingPracticeViewModel) -> some View {
        VStack(spacing: 8) {
            Text("Practice Complete")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Score: \(Int(vm.score))%")
                .font(.title.bold())
                .foregroundStyle(scoreColor(vm.score))

            if scoreSaved {
                Text("Score saved")
                    .font(.caption)
                    .foregroundStyle(Color.intonavioTextSecondary)
            }

            Button("Try Again") {
                scoreSaved = false
                vm.restart()
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: 200)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.intonavioSurface)
        .onAppear { saveScore(vm) }
    }

    func saveScore(_ vm: RecordingPracticeViewModel) {
        guard !scoreSaved else { return }
        let repo = ScoreRepository(modelContext: modelContext)
        let songId = "recording:\(recording.id.uuidString)"
        repo.saveScore(songId: songId, phraseIndex: nil, score: vm.score)
        scoreSaved = true
    }

    func scoreColor(_ score: Double) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return .yellow }
        return .red
    }
}

// MARK: - Setup

private extension RecordingPracticeView {
    func setupIfNeeded() {
        guard viewModel == nil else { return }
        let vm = RecordingPracticeViewModel(recording: recording)
        vm.prepare()
        viewModel = vm
    }
}
