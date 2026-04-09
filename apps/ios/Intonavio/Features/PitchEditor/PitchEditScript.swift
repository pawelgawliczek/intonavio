import Foundation

/// How an added passage blends with the existing base frames.
enum DrawMode: String, Codable, Sendable {
    case replace
    case additive
}

/// Half-open time window `[start, end)` in seconds.
struct TimeRange: Codable, Sendable, Equatable {
    let start: Double
    let end: Double
}

/// A single edit operation applied on top of the base variant frames.
enum PitchEditOp: Codable, Sendable, Identifiable, Equatable {
    case useVariant(id: UUID, range: TimeRange, source: StemSource)
    case despike(id: UUID, range: TimeRange, maxJumpSemitones: Double)
    case mute(id: UUID, range: TimeRange)
    case shiftOctave(id: UUID, range: TimeRange, octaves: Int)
    case shiftSemitones(id: UUID, range: TimeRange, semitones: Int)
    case addPassage(id: UUID, range: TimeRange, frames: [ReferencePitchFrame], mode: DrawMode)

    var id: UUID {
        switch self {
        case .useVariant(let id, _, _),
             .despike(let id, _, _),
             .mute(let id, _),
             .shiftOctave(let id, _, _),
             .shiftSemitones(let id, _, _),
             .addPassage(let id, _, _, _):
            return id
        }
    }

    var range: TimeRange {
        switch self {
        case .useVariant(_, let r, _),
             .despike(_, let r, _),
             .mute(_, let r),
             .shiftOctave(_, let r, _),
             .shiftSemitones(_, let r, _),
             .addPassage(_, let r, _, _):
            return r
        }
    }

    var displayName: String {
        switch self {
        case .useVariant(_, _, let source): return "Use \(source.displayName)"
        case .despike: return "Despike"
        case .mute: return "Mute"
        case .shiftOctave(_, _, let oct): return "Shift \(oct > 0 ? "+" : "")\(oct) oct"
        case .shiftSemitones(_, _, let st): return "Shift \(st > 0 ? "+" : "")\(st) st"
        case .addPassage(_, _, _, let mode): return "Draw (\(mode.rawValue))"
        }
    }

    private enum Kind: String, Codable {
        case useVariant, despike, mute, shiftOctave, shiftSemitones, addPassage
    }

    private enum CodingKeys: String, CodingKey {
        case type, id, range, source, maxJumpSemitones, octaves, semitones, frames, mode
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .type)
        let id = try c.decode(UUID.self, forKey: .id)
        let range = try c.decode(TimeRange.self, forKey: .range)
        switch kind {
        case .useVariant:
            let source = try c.decode(StemSource.self, forKey: .source)
            self = .useVariant(id: id, range: range, source: source)
        case .despike:
            let mjs = try c.decode(Double.self, forKey: .maxJumpSemitones)
            self = .despike(id: id, range: range, maxJumpSemitones: mjs)
        case .mute:
            self = .mute(id: id, range: range)
        case .shiftOctave:
            let octaves = try c.decode(Int.self, forKey: .octaves)
            self = .shiftOctave(id: id, range: range, octaves: octaves)
        case .shiftSemitones:
            let semitones = try c.decode(Int.self, forKey: .semitones)
            self = .shiftSemitones(id: id, range: range, semitones: semitones)
        case .addPassage:
            let frames = try c.decode([ReferencePitchFrame].self, forKey: .frames)
            let mode = try c.decode(DrawMode.self, forKey: .mode)
            self = .addPassage(id: id, range: range, frames: frames, mode: mode)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(range, forKey: .range)
        switch self {
        case .useVariant(_, _, let source):
            try c.encode(Kind.useVariant, forKey: .type)
            try c.encode(source, forKey: .source)
        case .despike(_, _, let mjs):
            try c.encode(Kind.despike, forKey: .type)
            try c.encode(mjs, forKey: .maxJumpSemitones)
        case .mute:
            try c.encode(Kind.mute, forKey: .type)
        case .shiftOctave(_, _, let octaves):
            try c.encode(Kind.shiftOctave, forKey: .type)
            try c.encode(octaves, forKey: .octaves)
        case .shiftSemitones(_, _, let semitones):
            try c.encode(Kind.shiftSemitones, forKey: .type)
            try c.encode(semitones, forKey: .semitones)
        case .addPassage(_, _, let frames, let mode):
            try c.encode(Kind.addPassage, forKey: .type)
            try c.encode(frames, forKey: .frames)
            try c.encode(mode, forKey: .mode)
        }
    }
}

extension ReferencePitchFrame: Equatable {
    static func == (lhs: ReferencePitchFrame, rhs: ReferencePitchFrame) -> Bool {
        lhs.time == rhs.time
            && lhs.frequency == rhs.frequency
            && lhs.isVoiced == rhs.isVoiced
            && lhs.midiNote == rhs.midiNote
            && lhs.rms == rhs.rms
    }
}

/// Local-only edit script layered over a song's base pitch variant.
struct PitchEditScript: Codable, Sendable, Equatable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let songId: String
    var baseVariantId: String
    var operations: [PitchEditOp]
    var updatedAt: Date

    init(
        schemaVersion: Int = PitchEditScript.currentSchemaVersion,
        songId: String,
        baseVariantId: String,
        operations: [PitchEditOp] = [],
        updatedAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.songId = songId
        self.baseVariantId = baseVariantId
        self.operations = operations
        self.updatedAt = updatedAt
    }
}
