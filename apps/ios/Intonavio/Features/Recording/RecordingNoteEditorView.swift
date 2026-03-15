import SwiftData
import SwiftUI

/// Allows editing detected notes in a recording: delete artifacts,
/// adjust pitch, and tap a note to loop it during practice.
struct RecordingNoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let recording: Recording
    var onLoopNote: ((DetectedNote) -> Void)?

    @State private var notes: [DetectedNote] = []
    @State private var hasChanges = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(notes.enumerated()), id: \.offset) { index, note in
                    noteRow(note, index: index)
                }
                .onDelete { indexSet in
                    notes.remove(atOffsets: indexSet)
                    hasChanges = true
                }
            }
            .navigationTitle("Edit Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAndDismiss() }
                        .disabled(!hasChanges)
                }
            }
        }
        .onAppear { loadNotes() }
    }
}

// MARK: - Note Row

private extension RecordingNoteEditorView {
    func noteRow(_ note: DetectedNote, index: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(note.name)
                    .font(.headline)
                HStack(spacing: 8) {
                    Text("\(Int(note.averageHz)) Hz")
                    Text(String(format: "%.1fs", note.duration))
                    Text(String(format: "@ %.1fs", note.startTime))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Button {
                    shiftNote(at: index, by: -1)
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.title3)
                }
                .buttonStyle(.plain)

                Text("MIDI \(note.midi)")
                    .font(.caption.monospacedDigit())
                    .frame(width: 60)

                Button {
                    shiftNote(at: index, by: 1)
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }

            if onLoopNote != nil {
                Button {
                    onLoopNote?(note)
                    dismiss()
                } label: {
                    Image(systemName: "repeat.1")
                        .font(.title3)
                        .foregroundStyle(Color.intonavioAmber)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Logic

private extension RecordingNoteEditorView {
    func loadNotes() {
        do {
            notes = try JSONDecoder().decode(
                [DetectedNote].self, from: recording.detectedNotes
            )
        } catch {
            AppLogger.recording.error(
                "Failed to decode notes: \(error.localizedDescription)"
            )
        }
    }

    func shiftNote(at index: Int, by semitones: Int) {
        let old = notes[index]
        let newMidi = old.midi + semitones
        guard newMidi >= 0, newMidi <= 127 else { return }

        let newHz = Double(NoteMapper.midiToFrequency(Float(newMidi)))
        let info = NoteMapper.noteInfo(forMidi: newMidi)

        notes[index] = DetectedNote(
            midi: newMidi,
            name: info.fullName,
            startTime: old.startTime,
            duration: old.duration,
            averageHz: newHz,
            confidence: old.confidence
        )
        hasChanges = true
    }

    func saveAndDismiss() {
        do {
            let hopDuration = Double(PitchConstants.hopSize)
                / Double(PitchConstants.sampleRate)

            var frames = try JSONDecoder().decode(
                [ReferencePitchFrame].self, from: recording.pitchFrames
            )

            frames = applyEdits(to: frames, notes: notes, hopDuration: hopDuration)

            recording.pitchFrames = try JSONEncoder().encode(frames)
            recording.detectedNotes = try JSONEncoder().encode(notes)
            recording.noteCount = notes.count

            let midiValues = notes.map(\.midi)
            recording.lowestMidi = midiValues.min() ?? 60
            recording.highestMidi = midiValues.max() ?? 72

            try modelContext.save()
            AppLogger.recording.info(
                "Saved \(notes.count) edited notes for '\(recording.name)'"
            )
        } catch {
            AppLogger.recording.error(
                "Save edits failed: \(error.localizedDescription)"
            )
        }
        dismiss()
    }

    /// Apply note edits back to pitch frames: mark deleted regions as
    /// unvoiced, update frequency/midi for shifted notes.
    func applyEdits(
        to frames: [ReferencePitchFrame],
        notes: [DetectedNote],
        hopDuration: Double
    ) -> [ReferencePitchFrame] {
        // Build a lookup of edited note ranges
        var noteRanges: [(range: ClosedRange<Int>, note: DetectedNote)] = []
        for note in notes {
            let startIdx = Int(note.startTime / hopDuration)
            let endIdx = Int((note.startTime + note.duration) / hopDuration)
            let clamped = startIdx...min(endIdx, frames.count - 1)
            noteRanges.append((clamped, note))
        }

        return frames.enumerated().map { index, frame in
            // Check if this frame belongs to an edited note
            if let match = noteRanges.first(where: { $0.range.contains(index) }) {
                let note = match.note
                return ReferencePitchFrame(
                    time: frame.time,
                    frequency: note.averageHz,
                    isVoiced: true,
                    midiNote: Double(note.midi),
                    rms: frame.rms
                )
            }

            // Frame doesn't belong to any note — mark unvoiced
            guard frame.isVoiced else { return frame }
            return ReferencePitchFrame(
                time: frame.time, frequency: nil,
                isVoiced: false, midiNote: nil, rms: frame.rms
            )
        }
    }
}

#Preview {
    RecordingNoteEditorView(
        recording: Recording(
            name: "Test",
            duration: 5.0,
            audioFileName: "test.caf",
            pitchFrames: Data(),
            detectedNotes: Data(),
            noteCount: 0,
            lowestMidi: 60,
            highestMidi: 72
        )
    )
    .modelContainer(for: Recording.self, inMemory: true)
}
