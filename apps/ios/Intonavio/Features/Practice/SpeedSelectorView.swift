import SwiftUI

struct SpeedSelectorView: View {
    @Bindable var viewModel: PracticeViewModel

    private let speeds: [Double] = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        HStack(spacing: 6) {
            Text("Speed:")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(speeds, id: \.self) { rate in
                Button(rateLabel(rate)) {
                    viewModel.setSpeed(rate)
                }
                .buttonStyle(.bordered)
                .tint(viewModel.playbackRate == rate ? Color.intonavioIce : Color.intonavioTextSecondary)
                .controlSize(.mini)
            }
        }
    }

    private func rateLabel(_ rate: Double) -> String {
        rate == 1.0 ? "1x" : String(format: "%.2gx", rate)
    }
}

#Preview {
    SpeedSelectorView(viewModel: PracticeViewModel(songId: "s1", videoId: "v1"))
}
