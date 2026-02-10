import SwiftUI

struct ContentView: View {
    @State private var viewModel = PlayerViewModel()
    @State private var videoIdText: String = "uBJdwRPO1QE"

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("YouTube Looping Spike")
                    .font(.title2.bold())

                videoIdField
                playerView
                timelineDisplay
                PlaybackControlsView(viewModel: viewModel)
                LoopControlsView(viewModel: viewModel)
                diagnostics

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { viewModel.configure() }
    }
}

// MARK: - Subviews

private extension ContentView {
    var videoIdField: some View {
        HStack {
            TextField("Video ID", text: $videoIdText)
                .textFieldStyle(.roundedBorder)
                .font(.caption.monospaced())
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit {
                    viewModel.videoId = videoIdText
                }

            Text(viewModel.isPlayerReady ? "Ready" : "Loading")
                .font(.caption)
                .foregroundStyle(
                    viewModel.isPlayerReady ? .green : .orange
                )
        }
    }

    var playerView: some View {
        YouTubePlayerView(
            videoId: viewModel.videoId,
            bridge: viewModel.bridge,
            server: viewModel.server,
            onWebViewReady: { webView in
                viewModel.onWebViewReady(webView)
            }
        )
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var timelineDisplay: some View {
        TimelineBarView(viewModel: viewModel)
    }

    var diagnostics: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Diagnostics")
                .font(.caption.bold())
            HStack(spacing: 16) {
                diagItem(
                    "Bridge Latency",
                    String(
                        format: "%.0fms",
                        viewModel.bridgeLatencyAvg
                    )
                )
                diagItem(
                    "Last Seek",
                    String(
                        format: "%.0fms",
                        viewModel.seekPrecisionLast
                    )
                )
                diagItem(
                    "Rate",
                    String(
                        format: "%.2gx",
                        viewModel.playbackRate
                    )
                )
            }
        }
        .font(.caption.monospacedDigit())
    }

    func diagItem(
        _ label: String,
        _ value: String
    ) -> some View {
        VStack {
            Text(label).foregroundStyle(.secondary)
            Text(value)
        }
    }

}

#Preview {
    ContentView()
}
