import SwiftData
import SwiftUI

struct SongPracticeView: View {
    var songId: String = ""
    var videoId: String = ""
    var stems: [StemResponse] = []
    var hasPitchData: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: PracticeViewModel?
    @State private var isShowingProgress = false

    var body: some View {
        mainContent
            #if os(macOS)
            .macKeyboardShortcuts(
                viewModel: viewModel,
                dismiss: dismiss
            )
            #endif
    }

    private var mainContent: some View {
        Group {
            if let vm = viewModel {
                practiceContent(vm)
            } else {
                ProgressView("Loading...")
            }
        }
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel != nil)
        .hideTabBarIfNeeded()
        .toolbar {
            if let vm = viewModel {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        vm.saveSongScore()
                        vm.stopPitchDetection()
                        vm.saveSessionIfNeeded()
                        vm.server.stop()
                        dismiss()
                    }
                }
                if vm.totalPhrases > 0 {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            isShowingProgress = true
                        } label: {
                            Image(systemName: "chart.bar.xaxis")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingProgress) {
            if let vm = viewModel {
                ProgressLogView(
                    songId: vm.songId,
                    totalPhrases: vm.totalPhrases,
                    scoreRepository: vm.scoreRepository,
                    onPhraseTap: { phraseIndex in
                        vm.setupPhraseLoop(phraseIndex: phraseIndex)
                        isShowingProgress = false
                    }
                )
            }
        }
        .onAppear { setupIfNeeded() }
        .onDisappear {
            viewModel?.stopPitchDetection()
            viewModel?.saveSessionIfNeeded()
            viewModel?.sync?.stop()
            viewModel?.stemPlayer.teardown()
            viewModel?.server.stop()
            viewModel?.audioEngine.shutdown()
        }
    }
}

// MARK: - macOS Keyboard Shortcuts

#if os(macOS)
private struct SongPracticeKeyboardShortcuts: ViewModifier {
    let viewModel: PracticeViewModel?
    let dismiss: DismissAction

    func body(content: Content) -> some View {
        content
            .onKeyPress(.space) {
                guard let vm = viewModel else { return .ignored }
                if vm.loopState == .playing || vm.loopState == .looping {
                    vm.pause()
                } else {
                    vm.play()
                }
                return .handled
            }
            .onKeyPress("a", phases: .down) { press in
                guard press.modifiers.contains(.command) else { return .ignored }
                viewModel?.setMarkerA()
                return .handled
            }
            .onKeyPress("b", phases: .down) { press in
                guard press.modifiers.contains(.command) else { return .ignored }
                viewModel?.setMarkerB()
                return .handled
            }
            .onKeyPress(.escape) {
                viewModel?.clearLoop()
                return .handled
            }
            .onKeyPress("w", phases: .down) { press in
                guard press.modifiers.contains(.command) else { return .ignored }
                viewModel?.saveSongScore()
                viewModel?.stopPitchDetection()
                viewModel?.saveSessionIfNeeded()
                viewModel?.server.stop()
                dismiss()
                return .handled
            }
    }
}

private extension View {
    func macKeyboardShortcuts(
        viewModel: PracticeViewModel?,
        dismiss: DismissAction
    ) -> some View {
        modifier(SongPracticeKeyboardShortcuts(
            viewModel: viewModel,
            dismiss: dismiss
        ))
    }
}
#endif

// MARK: - Subviews

private extension SongPracticeView {
    func practiceContent(_ vm: PracticeViewModel) -> some View {
        ZStack {
            if vm.isPitchReady {
                pitchLayout(vm)
            } else {
                standardLayout(vm)
            }

            if !vm.isPlayerReady {
                loadingOverlay
            }
        }
    }

    /// Layout when pitch detection is active: video + piano roll split.
    func pitchLayout(_ vm: PracticeViewModel) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    videoPlayer(vm)
                        .frame(height: geometry.size.height * vm.layoutMode.videoFraction)
                    Divider()
                    PianoRollSection(viewModel: vm)
                    Divider()
                    controlsSection(vm)
                }

                if vm.isShowingLoopScore, let score = vm.lastLoopScore {
                    LoopScoreToastView(
                        score: score,
                        change: vm.loopScoreImprovement
                    )
                    .padding(.top, geometry.size.height * vm.layoutMode.videoFraction + 12)
                    .animation(.easeInOut(duration: 0.3), value: vm.isShowingLoopScore)
                }

                if vm.isShowingPhraseScore, let score = vm.currentPhraseScore {
                    PhraseScoreToastView(
                        score: score,
                        phraseIndex: vm.currentPhraseIndex ?? 0,
                        totalPhrases: vm.totalPhrases,
                        isNewBest: vm.isPhraseNewBest
                    )
                    .padding(.top, geometry.size.height * vm.layoutMode.videoFraction + 12)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: vm.isShowingPhraseScore)
                }

                if vm.isSongNewBest {
                    SongBestToastView(score: vm.songBestScore)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: vm.isSongNewBest)
                }
            }
        }
    }

    /// Standard layout: video at natural 16:9 aspect ratio, controls below.
    func standardLayout(_ vm: PracticeViewModel) -> some View {
        VStack(spacing: 0) {
            videoPlayer(vm)
                .aspectRatio(16 / 9, contentMode: .fit)
            Divider()
            PianoRollSection(viewModel: vm)
            Divider()
            controlsSection(vm)
        }
    }

    func videoPlayer(_ vm: PracticeViewModel) -> some View {
        YouTubePlayerView(
            videoId: vm.videoId,
            bridge: vm.bridge,
            server: vm.server,
            onWebViewReady: vm.onWebViewReady
        )
        .background(Color.black)
        .overlay {
            Color.clear.contentShape(Rectangle())
        }
    }

    func controlsSection(_ vm: PracticeViewModel) -> some View {
        ControlsBarView(viewModel: vm)
            .padding()
    }

    var loadingOverlay: some View {
        ZStack {
            Color.intonavioBackground.opacity(0.85)
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                Text("Preparing player...")
                    .font(.subheadline)
                    .foregroundStyle(Color.intonavioTextSecondary)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Piano Roll (isolated observation)

/// Separate View so high-frequency @Observable access (currentTime, detectedPoints)
/// is scoped here and doesn't trigger re-renders of the parent (controls, video).
private struct PianoRollSection: View {
    let viewModel: PracticeViewModel
    @State private var gestureState = PianoRollGestureState()
    @State private var momentumEngine = PianoRollMomentumEngine()

    private var displayTime: Double {
        let raw = gestureState.displayTime(playbackTime: viewModel.currentTime)
        return max(0, min(raw, viewModel.duration))
    }

    private var isPlaying: Bool {
        viewModel.loopState == .playing || viewModel.loopState == .looping
    }

    var body: some View {
        let windowStart = displayTime - 4.0
        let windowEnd = displayTime + 4.0
        let frames = viewModel.referenceStore.frames(
            from: windowStart, to: windowEnd
        )
        let visiblePoints = viewModel.detectedPoints.filter {
            $0.time >= windowStart && $0.time <= windowEnd
        }

        PianoRollView(
            mode: Binding(
                get: { viewModel.visualizationMode },
                set: { viewModel.visualizationMode = $0 }
            ),
            referenceFrames: frames,
            hopDuration: viewModel.referenceStore.hopDuration,
            detectedPoints: visiblePoints,
            currentTime: displayTime,
            currentNoteName: viewModel.pitchDetector?.latestResult?.noteName,
            centsDeviation: viewModel.pitchDetector?.latestResult?.centsDeviation ?? 0,
            accuracy: viewModel.scoringEngine?.currentAccuracy ?? .unvoiced,
            score: viewModel.scoringEngine?.overallScore ?? 0,
            isPitchReady: viewModel.isPitchReady,
            midiMin: viewModel.transposedMidiMin,
            midiMax: viewModel.transposedMidiMax,
            transposeSemitones: viewModel.transposeSemitones,
            zones: DifficultyLevel.current.zones,
            phraseIndex: viewModel.scoringEngine?.currentPhraseIndex,
            totalPhrases: viewModel.totalPhrases,
            gestureState: gestureState,
            momentumEngine: momentumEngine,
            songDuration: viewModel.duration,
            referenceStore: viewModel.referenceStore,
            playbackTime: gestureState.isBrowsing ? viewModel.currentTime : nil,
            onPause: { if isPlaying { viewModel.pause() } },
            onSeek: { time in
                viewModel.seek(to: time)
                gestureState.exitBrowsing()
            },
            onResume: {
                viewModel.seek(to: displayTime)
                viewModel.play()
                gestureState.exitBrowsing()
            },
            onSetupPhraseLoop: { phraseIndex in
                viewModel.setupPhraseLoop(phraseIndex: phraseIndex)
                gestureState.exitBrowsing()
            }
        )
        .onChange(of: viewModel.loopState) { _, newState in
            guard gestureState.isBrowsing else { return }
            if newState == .playing || newState == .looping {
                viewModel.seek(to: displayTime)
                gestureState.exitBrowsing()
            }
        }
    }
}

// MARK: - Setup

private extension SongPracticeView {
    func setupIfNeeded() {
        guard viewModel == nil else { return }
        let vm = PracticeViewModel(songId: songId, videoId: videoId)
        vm.stems = stems
        vm.scoreRepository = ScoreRepository(modelContext: modelContext)
        vm.configure()
        vm.preloadStems()
        vm.downloadPitchDataIfNeeded(
            hasPitchData: hasPitchData,
            apiClient: APIClient()
        )
        viewModel = vm
    }
}

#Preview {
    NavigationStack {
        SongPracticeView(songId: "song1", videoId: "dQw4w9WgXcQ")
    }
}
