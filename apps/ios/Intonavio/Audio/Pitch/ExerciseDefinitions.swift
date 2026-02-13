import Foundation

/// A single note in an exercise definition.
struct ExerciseNote: Sendable {
    let midiNote: Int
    let durationBeats: Double
    let isRest: Bool
    let hasVibrato: Bool

    init(
        midiNote: Int,
        durationBeats: Double = 1.0,
        isRest: Bool = false,
        hasVibrato: Bool = false
    ) {
        self.midiNote = midiNote
        self.durationBeats = durationBeats
        self.isRest = isRest
        self.hasVibrato = hasVibrato
    }

    static func rest(durationBeats: Double = 1.0) -> ExerciseNote {
        ExerciseNote(midiNote: 0, durationBeats: durationBeats, isRest: true)
    }
}

/// A complete exercise definition with notes and metadata.
struct ExerciseDefinition: Identifiable, Sendable {
    let id: String
    let name: String
    let category: ExerciseCategory
    let icon: String
    let description: String
    let defaultTempo: Int
    let notes: [ExerciseNote]

    var durationBeats: Double {
        notes.reduce(0) { $0 + $1.durationBeats }
    }
}

enum ExerciseCategory: String, CaseIterable, Sendable {
    case scales = "Scales"
    case arpeggios = "Arpeggios"
    case intervals = "Intervals"
    case vibrato = "Vibrato"
    case sustained = "Sustained"
}

/// Bundled exercise data for client-side pitch generation.
enum ExerciseDefinitions {
    // MARK: - Scales

    static let majorScaleC4 = ExerciseDefinition(
        id: "major-scale-c4",
        name: "Major Scale C4",
        category: .scales,
        icon: "arrow.up.right",
        description: "C major ascending and descending",
        defaultTempo: 80,
        notes: [60, 62, 64, 65, 67, 69, 71, 72, 71, 69, 67, 65, 64, 62, 60]
            .map { ExerciseNote(midiNote: $0) }
    )

    static let minorScaleA3 = ExerciseDefinition(
        id: "minor-scale-a3",
        name: "Minor Scale A3",
        category: .scales,
        icon: "arrow.down.right",
        description: "A natural minor ascending and descending",
        defaultTempo: 80,
        notes: [57, 59, 60, 62, 64, 65, 67, 69, 67, 65, 64, 62, 60, 59, 57]
            .map { ExerciseNote(midiNote: $0) }
    )

    static let chromaticC4 = ExerciseDefinition(
        id: "chromatic-c4",
        name: "Chromatic Scale C4",
        category: .scales,
        icon: "line.diagonal",
        description: "Half-step precision training",
        defaultTempo: 60,
        notes: (60...72).map { ExerciseNote(midiNote: $0) }
            + (60...71).reversed().map { ExerciseNote(midiNote: $0) }
    )

    // MARK: - Arpeggios

    static let majorArpeggioC4 = ExerciseDefinition(
        id: "major-arpeggio-c4",
        name: "Major Arpeggio C4",
        category: .arpeggios,
        icon: "chart.line.uptrend.xyaxis",
        description: "Root-3rd-5th-octave pattern",
        defaultTempo: 72,
        notes: [60, 64, 67, 72, 67, 64, 60]
            .map { ExerciseNote(midiNote: $0) }
    )

    static let minorArpeggioA3 = ExerciseDefinition(
        id: "minor-arpeggio-a3",
        name: "Minor Arpeggio A3",
        category: .arpeggios,
        icon: "chart.line.downtrend.xyaxis",
        description: "Minor triad pattern",
        defaultTempo: 72,
        notes: [57, 60, 64, 69, 64, 60, 57]
            .map { ExerciseNote(midiNote: $0) }
    )

    // MARK: - Intervals

    static let thirds = ExerciseDefinition(
        id: "thirds",
        name: "Thirds",
        category: .intervals,
        icon: "3.circle",
        description: "Major and minor thirds",
        defaultTempo: 72,
        notes: [60, 64, 62, 65, 64, 67, 65, 69, 67, 71, 69, 72]
            .map { ExerciseNote(midiNote: $0) }
    )

    static let fifths = ExerciseDefinition(
        id: "fifths",
        name: "Fifths",
        category: .intervals,
        icon: "5.circle",
        description: "Perfect fifths",
        defaultTempo: 66,
        notes: [60, 67, 62, 69, 64, 71, 65, 72]
            .map { ExerciseNote(midiNote: $0) }
    )

    static let octaves = ExerciseDefinition(
        id: "octaves",
        name: "Octaves",
        category: .intervals,
        icon: "8.circle",
        description: "Full octave jumps",
        defaultTempo: 60,
        notes: [48, 60, 50, 62, 52, 64, 53, 65, 55, 67]
            .map { ExerciseNote(midiNote: $0) }
    )

    // MARK: - Vibrato

    static let slowVibrato = ExerciseDefinition(
        id: "slow-vibrato",
        name: "Slow Vibrato",
        category: .vibrato,
        icon: "waveform.path.ecg",
        description: "Wide, controlled vibrato",
        defaultTempo: 60,
        notes: [60, 64, 67, 72].map {
            ExerciseNote(midiNote: $0, durationBeats: 4.0, hasVibrato: true)
        }
    )

    static let fastVibrato = ExerciseDefinition(
        id: "fast-vibrato",
        name: "Fast Vibrato",
        category: .vibrato,
        icon: "waveform.badge.magnifyingglass",
        description: "Narrow, quick vibrato",
        defaultTempo: 80,
        notes: [60, 64, 67, 72].map {
            ExerciseNote(midiNote: $0, durationBeats: 2.0, hasVibrato: true)
        }
    )

    // MARK: - Sustained

    static let sustainedNotes = ExerciseDefinition(
        id: "sustained-notes",
        name: "Sustained Notes",
        category: .sustained,
        icon: "timer",
        description: "Hold notes for breath control",
        defaultTempo: 60,
        notes: [60, 64, 67, 72].map {
            ExerciseNote(midiNote: $0, durationBeats: 8.0)
        }
    )

    // MARK: - All Exercises

    static let all: [ExerciseDefinition] = [
        majorScaleC4, minorScaleA3, chromaticC4,
        majorArpeggioC4, minorArpeggioA3,
        thirds, fifths, octaves,
        slowVibrato, fastVibrato,
        sustainedNotes,
    ]

    static func exercises(for category: ExerciseCategory) -> [ExerciseDefinition] {
        all.filter { $0.category == category }
    }
}
