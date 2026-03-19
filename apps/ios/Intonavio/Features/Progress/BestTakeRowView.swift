import SwiftUI

/// Shows best take playback controls and export button in the Progress view.
struct BestTakeRowView: View {
    let songId: String
    let instrumentalURL: URL?

    @State private var player: BestTakePlayer?
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var isShowingShareSheet = false
    @State private var errorMessage: String?
    @State private var syncOffset: TimeInterval = 0

    private var metadata: BestTakeMetadata? {
        BestTakeStorage.loadMetadata(songId: songId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            metadataRow
            playbackRow
            syncRow
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .onAppear {
            syncOffset = metadata?.syncOffset ?? 0
        }
        .onDisappear { player?.stop() }
        #if os(iOS)
        .sheet(isPresented: $isShowingShareSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
        #endif
    }
}

// MARK: - Subviews

private extension BestTakeRowView {
    var metadataRow: some View {
        HStack {
            if let meta = metadata {
                Label(
                    "\(Int(meta.score.rounded()))%",
                    systemImage: "star.fill"
                )
                .foregroundStyle(.yellow)
                .font(.subheadline.bold().monospacedDigit())

                Spacer()

                Text(meta.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var playbackRow: some View {
        HStack(spacing: 12) {
            playPauseButton
            muteVocalButton

            if let player {
                ProgressView(value: player.currentTime, total: max(player.duration, 0.01))
                    .tint(.accentColor)

                Text(formatTime(player.currentTime))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
            } else {
                ProgressView(value: 0)
                    .tint(.accentColor)
            }

            exportButton
        }
    }

    var syncRow: some View {
        HStack(spacing: 8) {
            Text("Sync")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                adjustSync(by: -0.05)
            } label: {
                Image(systemName: "minus.circle")
                    .font(.subheadline)
            }
            .buttonStyle(.plain)

            Text("\(Int(syncOffset * 1000))ms")
                .font(.caption.monospacedDigit())
                .frame(width: 50)

            Button {
                adjustSync(by: 0.05)
            } label: {
                Image(systemName: "plus.circle")
                    .font(.subheadline)
            }
            .buttonStyle(.plain)

            if syncOffset != 0 {
                Button("Reset") {
                    adjustSync(to: 0)
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
    }

    var playPauseButton: some View {
        Button {
            togglePlayback()
        } label: {
            Image(systemName: player?.isPlaying == true ? "pause.circle.fill" : "play.circle.fill")
                .font(.title2)
        }
        .buttonStyle(.plain)
        .disabled(instrumentalURL == nil)
    }

    var muteVocalButton: some View {
        Button {
            player?.isVocalMuted.toggle()
        } label: {
            Image(systemName: player?.isVocalMuted == true ? "mic.slash.fill" : "mic.fill")
                .font(.subheadline)
                .foregroundStyle(player?.isVocalMuted == true ? .secondary : .primary)
        }
        .buttonStyle(.plain)
        .disabled(player == nil)
    }

    var exportButton: some View {
        Button {
            exportBestTake()
        } label: {
            if isExporting {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "square.and.arrow.up")
            }
        }
        .buttonStyle(.plain)
        .disabled(isExporting || instrumentalURL == nil)
    }
}

// MARK: - Actions

private extension BestTakeRowView {
    func adjustSync(by delta: TimeInterval) {
        adjustSync(to: syncOffset + delta)
    }

    func adjustSync(to value: TimeInterval) {
        syncOffset = max(0, value)
        BestTakeStorage.updateSyncOffset(songId: songId, offset: syncOffset)
        // Reload player with new offset on next play
        player?.stop()
        player = nil
    }

    func togglePlayback() {
        if let player, player.isPlaying {
            player.pause()
            return
        }

        guard let instrumentalURL,
              let meta = metadata else { return }

        let vocalURL = BestTakeStorage.audioURL(for: songId)

        if player == nil {
            let newPlayer = BestTakePlayer()
            do {
                try newPlayer.load(
                    vocalURL: vocalURL,
                    instrumentalURL: instrumentalURL,
                    startOffset: meta.startOffset,
                    vocalSkip: meta.totalVocalSkip
                )
                player = newPlayer
            } catch {
                errorMessage = "Failed to load audio"
                return
            }
        }

        player?.play()
    }

    func exportBestTake() {
        guard let instrumentalURL, let meta = metadata else { return }

        let vocalURL = BestTakeStorage.audioURL(for: songId)
        isExporting = true
        errorMessage = nil

        Task {
            do {
                let url = try await BestTakeExporter.export(
                    vocalURL: vocalURL,
                    instrumentalURL: instrumentalURL,
                    startOffset: meta.startOffset,
                    vocalSkip: meta.totalVocalSkip,
                    outputName: "BestTake-\(songId)"
                )
                await MainActor.run {
                    exportURL = url
                    isExporting = false
                    isShowingShareSheet = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Export failed"
                    isExporting = false
                }
            }
        }
    }

    func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
