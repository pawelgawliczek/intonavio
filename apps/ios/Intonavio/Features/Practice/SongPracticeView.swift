import SwiftUI

struct SongPracticeView: View {
    var songId: String = ""
    var videoId: String = ""
    var stems: [StemResponse] = []

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: PracticeViewModel?

    var body: some View {
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
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if let vm = viewModel {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        vm.saveSessionIfNeeded()
                        vm.server.stop()
                        dismiss()
                    }
                }
            }
        }
        .onAppear { setupIfNeeded() }
        .onDisappear {
            viewModel?.saveSessionIfNeeded()
            viewModel?.sync?.stop()
            viewModel?.stemPlayer.teardown()
            viewModel?.server.stop()
        }
    }
}

// MARK: - Subviews

private extension SongPracticeView {
    func practiceContent(_ vm: PracticeViewModel) -> some View {
        ZStack {
            VStack(spacing: 0) {
                videoSection(vm)
                Divider()
                pitchPlaceholder
                Divider()
                controlsSection(vm)
            }

            if !vm.isPlayerReady {
                loadingOverlay
            }
        }
    }

    func videoSection(_ vm: PracticeViewModel) -> some View {
        YouTubePlayerView(
            videoId: vm.videoId,
            bridge: vm.bridge,
            server: vm.server,
            onWebViewReady: vm.onWebViewReady
        )
        .aspectRatio(16 / 9, contentMode: .fit)
        .background(Color.black)
    }

    var pitchPlaceholder: some View {
        VStack {
            Spacer()
            Text("Pitch Graph")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Coming in Phase 5")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    func controlsSection(_ vm: PracticeViewModel) -> some View {
        ControlsBarView(viewModel: vm)
            .padding()
    }

    var loadingOverlay: some View {
        ZStack {
            Color(.systemBackground).opacity(0.85)
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                Text("Preparing player...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Setup

private extension SongPracticeView {
    func setupIfNeeded() {
        guard viewModel == nil else { return }
        let vm = PracticeViewModel(songId: songId, videoId: videoId)
        vm.stems = stems
        vm.configure()
        vm.preloadStems()
        viewModel = vm
    }
}

#Preview {
    NavigationStack {
        SongPracticeView(songId: "song1", videoId: "dQw4w9WgXcQ")
    }
}
