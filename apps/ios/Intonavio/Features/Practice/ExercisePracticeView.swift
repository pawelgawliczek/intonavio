import SwiftUI

struct ExercisePracticeView: View {
    let exercise: ExerciseDefinition

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ExercisePracticeViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                exerciseContent(vm)
            } else {
                ProgressView("Preparing...")
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .hideTabBarIfNeeded()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
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

private extension ExercisePracticeView {
    func exerciseContent(_ vm: ExercisePracticeViewModel) -> some View {
        VStack(spacing: 0) {
            exerciseHeader(vm)
            Divider()
            pianoRollSection(vm)
            Divider()
            exerciseControls(vm)

            if vm.isComplete {
                completionBanner(vm)
            }
        }
    }

    func exerciseHeader(_ vm: ExercisePracticeViewModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.headline)
                Text(exercise.description)
                    .font(.caption)
                    .foregroundStyle(Color.intonavioTextSecondary)
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "metronome")
                    .foregroundStyle(.secondary)
                Text("\(vm.tempo) BPM")
                    .font(.subheadline.monospacedDigit())
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    func pianoRollSection(_ vm: ExercisePracticeViewModel) -> some View {
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
            transposeSemitones: 0,
            zones: DifficultyLevel.current.zones
        )
        .frame(maxHeight: .infinity)
    }

    func exerciseControls(_ vm: ExercisePracticeViewModel) -> some View {
        VStack(spacing: 8) {
            // Progress bar
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
                    Image(systemName: vm.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.largeTitle)
                }

                tempoStepper(vm)
            }
            .padding(.vertical, 8)

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

    func tempoStepper(_ vm: ExercisePracticeViewModel) -> some View {
        HStack(spacing: 4) {
            Button { vm.setTempo(max(40, vm.tempo - 5)) } label: {
                Image(systemName: "minus.circle")
            }
            Text("\(vm.tempo)")
                .font(.caption.monospacedDigit())
                .frame(width: 30)
            Button { vm.setTempo(min(200, vm.tempo + 5)) } label: {
                Image(systemName: "plus.circle")
            }
        }
        .font(.body)
    }

    func completionBanner(_ vm: ExercisePracticeViewModel) -> some View {
        VStack(spacing: 8) {
            Text("Exercise Complete")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Score: \(Int(vm.score))%")
                .font(.title.bold())
                .foregroundStyle(scoreColor(vm.score))
            Button("Try Again") { vm.restart() }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 200)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.intonavioSurface)
    }

    func scoreColor(_ score: Double) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return .yellow }
        return .red
    }
}

// MARK: - Setup

private extension ExercisePracticeView {
    func setupIfNeeded() {
        guard viewModel == nil else { return }
        let vm = ExercisePracticeViewModel(exercise: exercise)
        vm.prepare()
        viewModel = vm
    }
}

#Preview {
    NavigationStack {
        ExercisePracticeView(exercise: ExerciseDefinitions.majorScaleC4)
    }
}
