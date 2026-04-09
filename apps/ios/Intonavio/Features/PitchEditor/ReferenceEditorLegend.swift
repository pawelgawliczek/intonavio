import SwiftUI

extension StemSource {
    var editorColor: Color {
        switch self {
        case .studio: return .cyan
        case .draft: return .green
        }
    }
}

/// Compact layer legend overlay for the reference editor piano roll.
/// Shows colored dots for each pitch layer with tap-to-toggle visibility.
struct ReferenceEditorLegend: View {
    @Bindable var viewModel: ReferenceEditorViewModel

    private var baseSourceName: String {
        viewModel.baseSource?.displayName ?? "Base"
    }

    var body: some View {
        HStack(spacing: 10) {
            let editedLabel = viewModel.isDirty ? "Edited" : baseSourceName
            legendItem(color: .intonavioAmber, label: editedLabel, isOn: .constant(true))
            if viewModel.isDirty {
                legendItem(color: viewModel.baseSource?.editorColor ?? .blue, label: baseSourceName,
                           isOn: $viewModel.showBaseLayer)
            }
            if !viewModel.otherVariantFrames.isEmpty {
                let source = viewModel.otherVariantFrames.keys.first ?? .draft
                legendItem(color: source.editorColor, label: source.displayName,
                           isOn: $viewModel.showOtherVariantLayer)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func legendItem(
        color: Color,
        label: String,
        isOn: Binding<Bool>
    ) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(isOn.wrappedValue ? .primary : .tertiary)
            }
        }
        .buttonStyle(.plain)
        .opacity(isOn.wrappedValue ? 1 : 0.5)
    }
}
