import SwiftUI

struct GuideToneSettingsView: View {
    @AppStorage("guideToneInstrument") private var storedInstrument = 0
    @State private var previewTone: GuideTone?

    private var selectedInstrument: GuideToneInstrument {
        GuideToneInstrument(rawValue: storedInstrument) ?? .acousticGrandPiano
    }

    var body: some View {
        List {
            ForEach(GuideToneInstrument.groupedByCategory, id: \.category) { group in
                Section(group.category.rawValue) {
                    ForEach(group.instruments) { instrument in
                        Button {
                            selectInstrument(instrument)
                        } label: {
                            HStack {
                                Text(instrument.label)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if instrument == selectedInstrument {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Guide Tone Instrument")
    }

    private func selectInstrument(_ instrument: GuideToneInstrument) {
        storedInstrument = instrument.rawValue
        playPreview(instrument)
    }

    private func playPreview(_ instrument: GuideToneInstrument) {
        if previewTone == nil {
            previewTone = GuideTone(engine: AudioEngine())
        }
        guard let tone = previewTone else { return }
        tone.loadInstrument(instrument)
        tone.playPreview()
    }
}

#Preview {
    NavigationStack {
        GuideToneSettingsView()
    }
}
