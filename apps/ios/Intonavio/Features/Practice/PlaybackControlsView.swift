import SwiftUI

struct PlaybackControlsView: View {
    @Bindable var viewModel: PracticeViewModel

    var body: some View {
        HStack(spacing: 20) {
            Button {
                viewModel.seek(to: max(0, viewModel.currentTime - 5))
            } label: {
                Image(systemName: "gobackward.5")
            }

            Button(action: playPauseAction) {
                Image(systemName: playPauseIcon)
                    .font(.title)
            }

            Button {
                viewModel.seek(
                    to: min(viewModel.duration, viewModel.currentTime + 5)
                )
            } label: {
                Image(systemName: "goforward.5")
            }
        }
        .font(.title2)
        .foregroundStyle(.white)
    }
}

// MARK: - Helpers

private extension PlaybackControlsView {
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
    PlaybackControlsView(
        viewModel: PracticeViewModel(songId: "s1", videoId: "v1")
    )
}
