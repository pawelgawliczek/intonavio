import SwiftUI

struct LoopControlsView: View {
    @Bindable var viewModel: PracticeViewModel

    var body: some View {
        HStack(spacing: 8) {
            Button {
                viewModel.setMarkerA()
            } label: {
                Text("A").frame(minWidth: 28)
            }
            .disabled(!canSetA)

            Button {
                viewModel.setMarkerB()
            } label: {
                Text("B").frame(minWidth: 28)
            }
            .disabled(!canSetB)

            Button(action: viewModel.clearLoop) {
                Image(systemName: "xmark.circle")
            }
            .disabled(!hasLoop)

            if viewModel.loopCount > 0 {
                Text("\(viewModel.loopCount)x")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.bordered)
        .tint(Color.intonavioIce)
        .controlSize(.small)
    }
}

// MARK: - Helpers

private extension LoopControlsView {
    var canSetA: Bool {
        [.playing, .looping].contains(viewModel.loopState)
    }

    var canSetB: Bool {
        viewModel.markerA != nil
            && viewModel.loopState == .settingA
    }

    var hasLoop: Bool {
        viewModel.markerA != nil
    }
}

#Preview {
    LoopControlsView(viewModel: PracticeViewModel(songId: "s1", videoId: "v1"))
}
