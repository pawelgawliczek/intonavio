import SwiftData
import SwiftUI

struct SongPracticeView: View {
    var songId: String = ""
    var videoId: String = ""
    var stems: [StemResponse] = []
    var hasPitchData: Bool = false
    var isOffline: Bool = false
    var songTitle: String = ""
    var songArtist: String?
    var songDuration: Int = 0

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
                ZStack {
                    Color.intonavioBackground
                    ProgressView()
                        .controlSize(.large)
                }
                .ignoresSafeArea()
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
                        vm.stopOfflineTimer()
                        if !isOffline {
                            vm.saveSessionIfNeeded()
                            vm.server.stop()
                        }
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
                    instrumentalURL: vm.instrumentalStemURL,
                    onPhraseTap: { phraseIndex in
                        vm.setupPhraseLoop(phraseIndex: phraseIndex)
                        isShowingProgress = false
                    }
                )
            }
        }
        .onAppear { setupIfNeeded() }
        .onDisappear {
            viewModel?.cleanupBestTakeTemp()
            viewModel?.stopPitchDetection()
            viewModel?.stopOfflineTimer()
            if !isOffline {
                viewModel?.saveSessionIfNeeded()
                viewModel?.sync?.stop()
                viewModel?.server.stop()
            }
            viewModel?.stemPlayer.teardown()
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
            if vm.isOffline {
                offlineLayout(vm)
            } else if vm.isPitchReady && vm.layoutMode == .lyrics {
                lyricsLayout(vm)
            } else if vm.isPitchReady {
                videoLayout(vm)
            } else {
                standardLayout(vm)
            }

            if !vm.isPlayerReady {
                loadingOverlay
                    .transition(.opacity)
                    .animation(.easeOut(duration: 0.3), value: vm.isPlayerReady)
            }
        }
    }

    /// Offline layout: no video, lyrics panel or song header + piano roll.
    func offlineLayout(_ vm: PracticeViewModel) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    if vm.lyricsProvider.hasLyrics {
                        LyricsPanelSection(viewModel: vm)
                            .frame(height: geometry.size.height * 0.35)
                    } else {
                        offlineSongHeader
                    }
                    Divider()
                    PianoRollSection(viewModel: vm)
                    Divider()
                    controlsSection(vm)
                }

                toastOverlays(vm, topOffset: vm.lyricsProvider.hasLyrics
                    ? geometry.size.height * 0.35 + 12 : 56)
            }
        }
    }

    var offlineSongHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(songTitle.isEmpty ? "Offline Practice" : songTitle)
                    .font(.headline)
                    .lineLimit(1)
                if let artist = songArtist, !artist.isEmpty {
                    Text(artist)
                        .font(.caption)
                        .foregroundStyle(Color.intonavioTextSecondary)
                }
            }
            Spacer()
            Label("Offline", systemImage: "wifi.slash")
                .font(.caption)
                .foregroundStyle(Color.intonavioTextSecondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    /// Layout with YouTube video on top, piano roll below.
    func videoLayout(_ vm: PracticeViewModel) -> some View {
        GeometryReader { geometry in
            let topHeight = geometry.size.height * vm.layoutMode.topFraction
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    videoPlayer(vm)
                        .frame(height: topHeight)
                    Divider()
                    PianoRollSection(viewModel: vm)
                    Divider()
                    controlsSection(vm)
                }

                toastOverlays(vm, topOffset: topHeight + 12)
            }
        }
    }

    /// Layout with lyrics panel on top, piano roll below, video hidden.
    func lyricsLayout(_ vm: PracticeViewModel) -> some View {
        GeometryReader { geometry in
            let topHeight = geometry.size.height * vm.layoutMode.topFraction
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    LyricsPanelSection(viewModel: vm)
                        .frame(height: topHeight)
                    Divider()
                    PianoRollSection(viewModel: vm)
                    Divider()
                    controlsSection(vm)
                }

                // Hidden video player for audio sync
                videoPlayer(vm)
                    .frame(width: 0, height: 0)
                    .opacity(0)

                toastOverlays(vm, topOffset: topHeight + 12)
            }
        }
    }

    func toastOverlays(_ vm: PracticeViewModel, topOffset: CGFloat) -> some View {
        ZStack(alignment: .top) {
            if vm.isShowingLoopScore, let score = vm.lastLoopScore {
                LoopScoreToastView(
                    score: score,
                    change: vm.loopScoreImprovement
                )
                .padding(.top, topOffset)
                .animation(.easeInOut(duration: 0.3), value: vm.isShowingLoopScore)
            }

            if vm.isShowingPhraseScore, let score = vm.currentPhraseScore {
                PhraseScoreToastView(
                    score: score,
                    phraseIndex: vm.currentPhraseIndex ?? 0,
                    totalPhrases: vm.totalPhrases,
                    isNewBest: vm.isPhraseNewBest
                )
                .padding(.top, topOffset)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: vm.isShowingPhraseScore)
            }

            if vm.isSongNewBest, !vm.isShowingPerformanceSummary {
                SongBestToastView(score: vm.songBestScore, isNewBest: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: vm.isSongNewBest)
            }

            if vm.isSongScoreInvalidated {
                scoreInvalidatedBanner
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 120)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: vm.isSongScoreInvalidated)
            }

            if vm.isShowingPerformanceSummary, let summary = vm.performanceSummary {
                PerformanceSummaryView(
                    summary: summary,
                    onViewProgress: {
                        vm.isShowingPerformanceSummary = false
                        isShowingProgress = true
                    },
                    onPracticeWeakest: {
                        vm.isShowingPerformanceSummary = false
                        if let index = summary.weakestPhraseIndex {
                            vm.setupPhraseLoop(phraseIndex: index)
                        }
                    },
                    onRestart: {
                        vm.isShowingPerformanceSummary = false
                        vm.restart()
                    },
                    onDone: {
                        vm.isShowingPerformanceSummary = false
                        vm.saveSongScore()
                        vm.stopPitchDetection()
                        vm.stopOfflineTimer()
                        if !isOffline {
                            vm.saveSessionIfNeeded()
                            vm.server.stop()
                        }
                        dismiss()
                    }
                )
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: vm.isShowingPerformanceSummary)
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

    var scoreInvalidatedBanner: some View {
        Label(
            "Song score won't be recorded (seeked or looped)",
            systemImage: "info.circle"
        )
        .font(.caption)
        .foregroundStyle(Color.intonavioTextSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.intonavioSurface.opacity(0.9), in: Capsule())
    }

    var loadingOverlay: some View {
        ZStack {
            Color.intonavioBackground.opacity(0.85)
            if let vm = viewModel {
                loadingChecklist(vm)
            } else {
                ProgressView()
                    .controlSize(.large)
            }
        }
        .ignoresSafeArea()
    }

    func loadingChecklist(_ vm: PracticeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Setting up practice")
                .font(.headline)
                .padding(.bottom, 4)

            if !vm.isOffline {
                loadingRow(
                    label: "Player",
                    isLoading: !vm.isPlayerReady,
                    isDone: vm.isPlayerReady
                )
            }

            if !vm.stems.isEmpty {
                loadingRow(
                    label: stemLabel(vm),
                    isLoading: vm.isDownloadingStems,
                    isDone: vm.isStemsReady
                )
            }

            if hasPitchData {
                loadingRow(
                    label: "Pitch data",
                    isLoading: vm.isPitchLoading,
                    isDone: vm.isPitchReady
                )
            }

            loadingRow(
                label: "Lyrics",
                isLoading: vm.lyricsProvider.isLoading,
                isDone: vm.lyricsProvider.hasLyrics
            )
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.intonavioSurface)
        )
        .padding(.horizontal, 40)
    }

    func stemLabel(_ vm: PracticeViewModel) -> String {
        if vm.isStemsReady { return "Audio" }
        guard let detail = vm.stemDownloadDetail else { return "Audio" }
        return "Audio (\(detail) \(vm.stemsDownloadedCount + 1)/\(vm.stems.count))"
    }

    func loadingRow(
        label: String,
        isLoading: Bool,
        isDone: Bool
    ) -> some View {
        HStack(spacing: 10) {
            if isDone {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.body)
            } else if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 17, height: 17)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(Color.intonavioTextSecondary.opacity(0.4))
                    .font(.body)
            }
            Text(label)
                .font(.subheadline)
                .foregroundStyle(isDone
                    ? Color.intonavioTextSecondary
                    : Color.primary)
        }
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
            currentLyricLine: viewModel.layoutMode == .video
                ? viewModel.lyricsProvider.currentLine(at: displayTime)?.text : nil,
            nextLyricLine: viewModel.layoutMode == .video
                ? viewModel.lyricsProvider.nextLine(at: displayTime)?.text : nil,
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

// MARK: - Lyrics Panel (isolated observation)

/// Separate View for lyrics panel so currentTime observation is scoped here.
private struct LyricsPanelSection: View {
    let viewModel: PracticeViewModel

    var body: some View {
        let time = viewModel.currentTime
        let provider = viewModel.lyricsProvider

        if provider.hasLyrics {
            LyricsPanelView(
                previousLine: provider.previousLine(at: time)?.text,
                currentLine: provider.currentLine(at: time)?.text,
                nextLine: provider.nextLine(at: time)?.text
            )
        } else {
            lyricsUnavailable
        }
    }

    private var lyricsUnavailable: some View {
        VStack(spacing: 6) {
            Spacer()
            Image(systemName: "text.quote")
                .font(.title2)
                .foregroundStyle(Color.intonavioIce.opacity(0.5))
            Text("No lyrics available")
                .font(.subheadline)
                .foregroundStyle(Color.intonavioTextSecondary)
            Text("Tap the video icon to switch to video mode")
                .font(.caption)
                .foregroundStyle(Color.intonavioTextSecondary.opacity(0.7))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.intonavioBackground)
    }
}

// MARK: - Setup

private extension SongPracticeView {
    func setupIfNeeded() {
        guard viewModel == nil else { return }
        let vm = PracticeViewModel(
            songId: songId,
            videoId: videoId,
            isOffline: isOffline
        )
        vm.stems = stems
        vm.scoreRepository = ScoreRepository(modelContext: modelContext)
        vm.configure()
        vm.preloadStems()

        if isOffline {
            vm.setDurationFromStems()
        } else {
            vm.downloadPitchDataIfNeeded(
                hasPitchData: hasPitchData,
                apiClient: APIClient()
            )
        }

        vm.fetchLyricsIfNeeded(
            title: songTitle,
            artist: songArtist,
            duration: songDuration
        )

        viewModel = vm
    }
}

#Preview {
    NavigationStack {
        SongPracticeView(songId: "song1", videoId: "dQw4w9WgXcQ")
    }
}
