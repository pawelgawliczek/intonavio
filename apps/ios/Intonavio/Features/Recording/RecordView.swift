import SwiftUI
import SwiftData

struct RecordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = RecordViewModel()

    let importURL: URL?

    init(importURL: URL? = nil) {
        self.importURL = importURL
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                switch viewModel.state {
                case .idle:
                    idleContent
                case .recording:
                    recordingContent
                case .analyzing:
                    analyzingContent
                case .review(let notes):
                    reviewContent(notes)
                case .error(let message):
                    errorContent(message)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.intonavioBackground.ignoresSafeArea())
            .navigationTitle(importURL != nil ? "Import" : "Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                if let importURL {
                    viewModel.importAudioFile(url: importURL)
                }
            }
        }
    }
}

// MARK: - State Views

private extension RecordView {
    var idleContent: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Play a note on your instrument")
                .font(.headline)
                .foregroundStyle(Color.intonavioTextSecondary)
            recordButton(isRecording: false)
            timeLabel
            Spacer()
        }
    }

    var recordingContent: some View {
        VStack(spacing: 24) {
            Spacer()
            audioLevelMeter
            timeLabel
            recordButton(isRecording: true)
            Spacer()
        }
    }

    var analyzingContent: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Analyzing pitch...")
                .font(.headline)
                .foregroundStyle(Color.intonavioTextSecondary)
            Spacer()
        }
    }

    func reviewContent(_ notes: [DetectedNote]) -> some View {
        VStack(spacing: 16) {
            detectedNotesList(notes)

            TextField("Name this recording", text: $viewModel.recordingName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            HStack(spacing: 16) {
                if !viewModel.isImportMode {
                    Button("Re-record") { viewModel.reRecord() }
                        .buttonStyle(SecondaryButtonStyle())
                }
                Button("Save") { saveAndDismiss() }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    func errorContent(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(message)
                .font(.body)
                .foregroundStyle(Color.intonavioTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Try Again") { viewModel.reRecord() }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 200)
            Spacer()
        }
    }
}

// MARK: - Components

private extension RecordView {
    func recordButton(isRecording: Bool) -> some View {
        Button {
            if isRecording {
                viewModel.stopRecording()
            } else {
                viewModel.startRecording()
            }
        } label: {
            Circle()
                .fill(isRecording ? Color.red : Color.intonavioMagenta)
                .frame(width: 80, height: 80)
                .overlay {
                    if isRecording {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white)
                            .frame(width: 28, height: 28)
                    } else {
                        Circle()
                            .fill(.white)
                            .frame(width: 28, height: 28)
                    }
                }
                .shadow(color: isRecording ? .red.opacity(0.4) : .clear, radius: 12)
        }
    }

    var audioLevelMeter: some View {
        let normalizedLevel = min(1.0, viewModel.audioLevel * 10)
        return RoundedRectangle(cornerRadius: 4)
            .fill(LinearGradient.intonavio)
            .frame(
                width: 200 * CGFloat(normalizedLevel),
                height: 8
            )
            .frame(width: 200, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.intonavioSurface)
                    .frame(width: 200)
            )
            .animation(.easeOut(duration: 0.05), value: normalizedLevel)
    }

    var timeLabel: some View {
        Text(formatTime(viewModel.currentDuration))
            .font(.title2.monospacedDigit())
            .foregroundStyle(Color.intonavioTextSecondary)
    }

    func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let frac = Int((seconds.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d / 0:30", mins, secs, frac)
    }

    func detectedNotesList(_ notes: [DetectedNote]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(notes.count) note\(notes.count == 1 ? "" : "s") detected")
                    .font(.headline)
                    .padding(.horizontal)

                ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                    noteRow(note)
                }
            }
            .padding(.vertical)
        }
    }

    func noteRow(_ note: DetectedNote) -> some View {
        HStack {
            Text(note.name)
                .font(.title3.bold())
                .foregroundStyle(.white)
                .frame(width: 50, alignment: .leading)
            Text("\(Int(note.averageHz)) Hz")
                .font(.caption.monospacedDigit())
                .foregroundStyle(Color.intonavioTextSecondary)
            Spacer()
            Text(String(format: "%.1fs", note.duration))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Color.intonavioTextSecondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    func saveAndDismiss() {
        guard viewModel.save(modelContext: modelContext) != nil else { return }
        dismiss()
    }
}

#Preview {
    RecordView()
        .modelContainer(for: Recording.self, inMemory: true)
}
