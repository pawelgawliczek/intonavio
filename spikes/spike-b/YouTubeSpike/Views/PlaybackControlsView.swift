import SwiftUI

struct PlaybackControlsView: View {
    @Bindable var viewModel: PlayerViewModel

    var body: some View {
        VStack(spacing: 12) {
            transportButtons
            speedSelector
            muteToggle
        }
    }
}

// MARK: - Subviews

private extension PlaybackControlsView {
    var transportButtons: some View {
        HStack(spacing: 20) {
            Button(action: { viewModel.seek(to: max(0, viewModel.currentTime - 5)) }) {
                Image(systemName: "gobackward.5")
            }

            Button(action: playPauseAction) {
                Image(systemName: playPauseIcon)
                    .font(.title)
            }

            Button(action: viewModel.stop) {
                Image(systemName: "stop.fill")
            }

            Button(action: { viewModel.seek(to: min(viewModel.duration, viewModel.currentTime + 5)) }) {
                Image(systemName: "goforward.5")
            }
        }
        .font(.title2)
    }

    var speedSelector: some View {
        HStack(spacing: 8) {
            Text("Speed:")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(speeds, id: \.self) { rate in
                Button(rateLabel(rate)) {
                    viewModel.setSpeed(rate)
                }
                .buttonStyle(.bordered)
                .tint(
                    viewModel.playbackRate == rate
                        ? .blue : .gray
                )
                .controlSize(.small)
            }
        }
    }

    var muteToggle: some View {
        Button(action: viewModel.toggleMute) {
            Label(
                viewModel.isMuted ? "Unmute" : "Mute",
                systemImage: viewModel.isMuted
                    ? "speaker.slash.fill"
                    : "speaker.wave.2.fill"
            )
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

// MARK: - Helpers

private extension PlaybackControlsView {
    var speeds: [Double] {
        [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    }

    func rateLabel(_ rate: Double) -> String {
        rate == 1.0 ? "1x" : String(format: "%.2gx", rate)
    }

    var playPauseIcon: String {
        switch viewModel.loopState {
        case .idle, .paused:
            return "play.fill"
        default:
            return "pause.fill"
        }
    }

    func playPauseAction() {
        switch viewModel.loopState {
        case .idle, .paused:
            viewModel.play()
        default:
            viewModel.pause()
        }
    }
}

#Preview {
    PlaybackControlsView(viewModel: PlayerViewModel())
}
