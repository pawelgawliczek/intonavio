import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Horizontal scroll section showing saved recordings on HomeView.
struct RecordingsSectionView: View {
    @Query(sort: \Recording.createdAt, order: .reverse)
    private var recordings: [Recording]
    @Environment(\.modelContext) private var modelContext
    @State private var showRecordSheet = false
    @State private var showImportPicker = false
    @State private var showImportSheet = false
    @State private var importURL: URL?
    @State private var recordingToDelete: Recording?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recordings")
                .font(.title2.bold())
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    addRecordCard
                    addImportCard
                    ForEach(recordings) { recording in
                        NavigationLink {
                            RecordingPracticeView(recording: recording)
                        } label: {
                            recordingCard(recording)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                recordingToDelete = recording
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showRecordSheet) {
            RecordView()
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importURL = url
                    showImportSheet = true
                }
            case .failure(let error):
                AppLogger.recording.error(
                    "File picker failed: \(error.localizedDescription)"
                )
            }
        }
        .sheet(isPresented: $showImportSheet) {
            if let importURL {
                RecordView(importURL: importURL)
            }
        }
        .confirmationDialog(
            "Delete Recording?",
            isPresented: Binding(
                get: { recordingToDelete != nil },
                set: { if !$0 { recordingToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let recording = recordingToDelete {
                    deleteRecording(recording)
                }
                recordingToDelete = nil
            }
        } message: {
            if let recording = recordingToDelete {
                Text("\"\(recording.name)\" will be permanently deleted.")
            }
        }
    }
}

// MARK: - Cards

private extension RecordingsSectionView {
    var addRecordCard: some View {
        Button { showRecordSheet = true } label: {
            VStack(spacing: 8) {
                Image(systemName: "mic.badge.plus")
                    .font(.title2)
                    .foregroundStyle(Color.intonavioIce)
                    .frame(width: 60, height: 60)
                    .background(
                        Color.intonavioSurface,
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                Text("Record")
                    .font(.caption)
                    .foregroundStyle(.white)
            }
            .frame(width: 80)
        }
        .buttonStyle(.plain)
    }

    var addImportCard: some View {
        Button { showImportPicker = true } label: {
            VStack(spacing: 8) {
                Image(systemName: "doc.badge.plus")
                    .font(.title2)
                    .foregroundStyle(Color.intonavioIce)
                    .frame(width: 60, height: 60)
                    .background(
                        Color.intonavioSurface,
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                Text("Import")
                    .font(.caption)
                    .foregroundStyle(.white)
            }
            .frame(width: 80)
        }
        .buttonStyle(.plain)
    }

    func deleteRecording(_ recording: Recording) {
        // Delete audio file from Documents/
        let docsURL = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        )[0]
        let audioURL = docsURL.appendingPathComponent(recording.audioFileName)
        let dirURL = audioURL.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: dirURL)

        // Delete SwiftData record
        modelContext.delete(recording)
        try? modelContext.save()
        AppLogger.recording.info("Deleted recording '\(recording.name)'")
    }

    func recordingCard(_ recording: Recording) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(spacing: 4) {
                Text(recording.name)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 80, height: 60)
            .background(
                Color.intonavioSurface,
                in: RoundedRectangle(cornerRadius: 12)
            )

            HStack(spacing: 2) {
                Text("\(recording.noteCount)")
                    .font(.caption2.monospacedDigit())
                Image(systemName: "music.note")
                    .font(.caption2)
            }
            .foregroundStyle(Color.intonavioTextSecondary)
            .frame(width: 80)
        }
        .frame(width: 80)
    }
}

#Preview {
    NavigationStack {
        RecordingsSectionView()
    }
    .modelContainer(for: Recording.self, inMemory: true)
}
