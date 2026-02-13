import SwiftUI

/// Compact controls bar at the bottom of the practice screen.
struct ControlsBarView: View {
    @Bindable var viewModel: PracticeViewModel

    var body: some View {
        VStack(spacing: 8) {
            TimelineBarView(viewModel: viewModel)
            PlaybackControlsView(viewModel: viewModel)
            HStack {
                if viewModel.isStemsReady {
                    audioSourceButtons
                }
                Spacer()
                LoopControlsView(viewModel: viewModel)
            }
            SpeedSelectorView(viewModel: viewModel)
        }
    }
}

// MARK: - Audio Source Buttons

private extension ControlsBarView {
    var audioSourceButtons: some View {
        HStack(spacing: 4) {
            sourceButton(icon: "speaker.wave.2.fill", mode: .original)
            sourceButton(icon: "mic.fill", mode: .vocalsOnly)
            sourceButton(icon: "guitars.fill", mode: .instrumental)
        }
    }

    func sourceButton(icon: String, mode: AudioMode) -> some View {
        let isSelected = viewModel.audioMode == mode
        return Button {
            viewModel.setAudioMode(mode)
        } label: {
            Image(systemName: icon)
                .font(.body)
                .frame(width: 34, height: 34)
                .foregroundStyle(isSelected ? .white : .secondary)
                .background(
                    isSelected ? Color.accentColor : Color(.tertiarySystemFill),
                    in: RoundedRectangle(cornerRadius: 6)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ControlsBarView(
        viewModel: PracticeViewModel(songId: "s1", videoId: "v1")
    )
    .padding()
}
