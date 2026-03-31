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
                if viewModel.isPitchReady {
                    pitchControls
                }
                Spacer()
                LoopControlsView(viewModel: viewModel)
            }
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
                .foregroundStyle(isSelected ? Color.intonavioIce : Color.intonavioTextSecondary)
                .background(
                    isSelected ? Color.intonavioIce.opacity(0.15) : Color.intonavioSurface,
                    in: RoundedRectangle(cornerRadius: 6)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pitch Controls

private extension ControlsBarView {
    var pitchControls: some View {
        HStack(spacing: 8) {
            transposePicker
            layoutToggle
            vizModePicker
        }
    }

    var transposePicker: some View {
        let semitones = viewModel.transposeSemitones
        let isActive = semitones != 0
        let icon = semitones > 0
            ? "arrow.up"
            : semitones < 0 ? "arrow.down" : "arrow.up.arrow.down"
        let badgeText = TransposeInterval(rawValue: semitones)?.shortLabel

        return Menu {
            ForEach(TransposeInterval.allCases) { interval in
                Button {
                    viewModel.setTranspose(interval.rawValue)
                } label: {
                    HStack {
                        Text(interval.label)
                        if semitones == interval.rawValue {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: icon)
                .font(.body)
                .frame(width: 34, height: 34)
                .foregroundStyle(isActive ? Color.intonavioIce : Color.intonavioTextSecondary)
                .background(
                    isActive ? Color.intonavioIce.opacity(0.15) : Color.intonavioSurface,
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .overlay(alignment: .topTrailing) {
                    if let badgeText, isActive {
                        Text(badgeText)
                            .font(.system(size: 9, weight: .bold).monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(Color.intonavioIce, in: Capsule())
                            .offset(x: 6, y: -6)
                    }
                }
        }
    }

    var layoutToggle: some View {
        let isVideo = viewModel.layoutMode == .video
        return Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                viewModel.layoutMode = isVideo ? .lyrics : .video
            }
        } label: {
            Image(systemName: isVideo
                  ? "text.quote" : "play.rectangle.fill")
                .font(.body)
                .frame(width: 34, height: 34)
                .foregroundStyle(Color.intonavioTextSecondary)
                .background(
                    Color.intonavioSurface,
                    in: RoundedRectangle(cornerRadius: 6)
                )
        }
        .buttonStyle(.plain)
    }

    var vizModePicker: some View {
        Picker("Mode", selection: $viewModel.visualizationMode) {
            ForEach(VisualizationMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 160)
    }
}

#Preview {
    ControlsBarView(
        viewModel: PracticeViewModel(songId: "s1", videoId: "v1")
    )
    .padding()
}
