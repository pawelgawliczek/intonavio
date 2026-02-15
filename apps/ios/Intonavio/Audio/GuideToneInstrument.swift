import Foundation

/// General MIDI instrument categories (groups of 8 programs each).
enum GMCategory: String, CaseIterable, Identifiable {
    case piano = "Piano"
    case chromaticPercussion = "Chromatic Percussion"
    case organ = "Organ"
    case guitar = "Guitar"
    case bass = "Bass"
    case strings = "Strings"
    case ensemble = "Ensemble"
    case brass = "Brass"
    case reed = "Reed"
    case pipe = "Pipe"
    case synthLead = "Synth Lead"
    case synthPad = "Synth Pad"
    case synthEffects = "Synth Effects"
    case ethnic = "Ethnic"
    case percussive = "Percussive"
    case soundEffects = "Sound Effects"

    var id: String { rawValue }
}

/// All 128 General MIDI instruments with program numbers, labels, and categories.
enum GuideToneInstrument: Int, CaseIterable, Identifiable, Codable {
    // Piano (0-7)
    case acousticGrandPiano = 0
    case brightAcousticPiano = 1
    case electricGrandPiano = 2
    case honkyTonkPiano = 3
    case electricPiano1 = 4
    case electricPiano2 = 5
    case harpsichord = 6
    case clavinet = 7

    // Chromatic Percussion (8-15)
    case celesta = 8
    case glockenspiel = 9
    case musicBox = 10
    case vibraphone = 11
    case marimba = 12
    case xylophone = 13
    case tubularBells = 14
    case dulcimer = 15

    // Organ (16-23)
    case drawbarOrgan = 16
    case percussiveOrgan = 17
    case rockOrgan = 18
    case churchOrgan = 19
    case reedOrgan = 20
    case accordion = 21
    case harmonica = 22
    case tangoAccordion = 23

    // Guitar (24-31)
    case acousticGuitarNylon = 24
    case acousticGuitarSteel = 25
    case electricGuitarJazz = 26
    case electricGuitarClean = 27
    case electricGuitarMuted = 28
    case overdrivenGuitar = 29
    case distortionGuitar = 30
    case guitarHarmonics = 31

    // Bass (32-39)
    case acousticBass = 32
    case electricBassFinger = 33
    case electricBassPick = 34
    case fretlessBass = 35
    case slapBass1 = 36
    case slapBass2 = 37
    case synthBass1 = 38
    case synthBass2 = 39

    // Strings (40-47)
    case violin = 40
    case viola = 41
    case cello = 42
    case contrabass = 43
    case tremoloStrings = 44
    case pizzicatoStrings = 45
    case orchestralHarp = 46
    case timpani = 47

    // Ensemble (48-55)
    case stringEnsemble1 = 48
    case stringEnsemble2 = 49
    case synthStrings1 = 50
    case synthStrings2 = 51
    case choirAahs = 52
    case voiceOohs = 53
    case synthVoice = 54
    case orchestraHit = 55

    // Brass (56-63)
    case trumpet = 56
    case trombone = 57
    case tuba = 58
    case mutedTrumpet = 59
    case frenchHorn = 60
    case brassSection = 61
    case synthBrass1 = 62
    case synthBrass2 = 63

    // Reed (64-71)
    case sopranoSax = 64
    case altoSax = 65
    case tenorSax = 66
    case baritoneSax = 67
    case oboe = 68
    case englishHorn = 69
    case bassoon = 70
    case clarinet = 71

    // Pipe (72-79)
    case piccolo = 72
    case flute = 73
    case recorder = 74
    case panFlute = 75
    case blownBottle = 76
    case shakuhachi = 77
    case whistle = 78
    case ocarina = 79

    // Synth Lead (80-87)
    case lead1Square = 80
    case lead2Sawtooth = 81
    case lead3Calliope = 82
    case lead4Chiff = 83
    case lead5Charang = 84
    case lead6Voice = 85
    case lead7Fifths = 86
    case lead8BassLead = 87

    // Synth Pad (88-95)
    case pad1NewAge = 88
    case pad2Warm = 89
    case pad3Polysynth = 90
    case pad4Choir = 91
    case pad5Bowed = 92
    case pad6Metallic = 93
    case pad7Halo = 94
    case pad8Sweep = 95

    // Synth Effects (96-103)
    case fx1Rain = 96
    case fx2Soundtrack = 97
    case fx3Crystal = 98
    case fx4Atmosphere = 99
    case fx5Brightness = 100
    case fx6Goblins = 101
    case fx7Echoes = 102
    case fx8SciFi = 103

    // Ethnic (104-111)
    case sitar = 104
    case banjo = 105
    case shamisen = 106
    case koto = 107
    case kalimba = 108
    case bagpipe = 109
    case fiddle = 110
    case shanai = 111

    // Percussive (112-119)
    case tinkleBell = 112
    case agogo = 113
    case steelDrums = 114
    case woodblock = 115
    case taikoDrum = 116
    case melodicTom = 117
    case synthDrum = 118
    case reverseCymbal = 119

    // Sound Effects (120-127)
    case guitarFretNoise = 120
    case breathNoise = 121
    case seashore = 122
    case birdTweet = 123
    case telephoneRing = 124
    case helicopter = 125
    case applause = 126
    case gunshot = 127

    var id: Int { rawValue }

    var program: UInt8 { UInt8(rawValue) }

    var category: GMCategory {
        switch rawValue / 8 {
        case 0: .piano
        case 1: .chromaticPercussion
        case 2: .organ
        case 3: .guitar
        case 4: .bass
        case 5: .strings
        case 6: .ensemble
        case 7: .brass
        case 8: .reed
        case 9: .pipe
        case 10: .synthLead
        case 11: .synthPad
        case 12: .synthEffects
        case 13: .ethnic
        case 14: .percussive
        default: .soundEffects
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    var label: String {
        switch self {
        case .acousticGrandPiano: "Acoustic Grand Piano"
        case .brightAcousticPiano: "Bright Acoustic Piano"
        case .electricGrandPiano: "Electric Grand Piano"
        case .honkyTonkPiano: "Honky-Tonk Piano"
        case .electricPiano1: "Electric Piano 1"
        case .electricPiano2: "Electric Piano 2"
        case .harpsichord: "Harpsichord"
        case .clavinet: "Clavinet"
        case .celesta: "Celesta"
        case .glockenspiel: "Glockenspiel"
        case .musicBox: "Music Box"
        case .vibraphone: "Vibraphone"
        case .marimba: "Marimba"
        case .xylophone: "Xylophone"
        case .tubularBells: "Tubular Bells"
        case .dulcimer: "Dulcimer"
        case .drawbarOrgan: "Drawbar Organ"
        case .percussiveOrgan: "Percussive Organ"
        case .rockOrgan: "Rock Organ"
        case .churchOrgan: "Church Organ"
        case .reedOrgan: "Reed Organ"
        case .accordion: "Accordion"
        case .harmonica: "Harmonica"
        case .tangoAccordion: "Tango Accordion"
        case .acousticGuitarNylon: "Acoustic Guitar (Nylon)"
        case .acousticGuitarSteel: "Acoustic Guitar (Steel)"
        case .electricGuitarJazz: "Electric Guitar (Jazz)"
        case .electricGuitarClean: "Electric Guitar (Clean)"
        case .electricGuitarMuted: "Electric Guitar (Muted)"
        case .overdrivenGuitar: "Overdriven Guitar"
        case .distortionGuitar: "Distortion Guitar"
        case .guitarHarmonics: "Guitar Harmonics"
        case .acousticBass: "Acoustic Bass"
        case .electricBassFinger: "Electric Bass (Finger)"
        case .electricBassPick: "Electric Bass (Pick)"
        case .fretlessBass: "Fretless Bass"
        case .slapBass1: "Slap Bass 1"
        case .slapBass2: "Slap Bass 2"
        case .synthBass1: "Synth Bass 1"
        case .synthBass2: "Synth Bass 2"
        case .violin: "Violin"
        case .viola: "Viola"
        case .cello: "Cello"
        case .contrabass: "Contrabass"
        case .tremoloStrings: "Tremolo Strings"
        case .pizzicatoStrings: "Pizzicato Strings"
        case .orchestralHarp: "Orchestral Harp"
        case .timpani: "Timpani"
        case .stringEnsemble1: "String Ensemble 1"
        case .stringEnsemble2: "String Ensemble 2"
        case .synthStrings1: "Synth Strings 1"
        case .synthStrings2: "Synth Strings 2"
        case .choirAahs: "Choir Aahs"
        case .voiceOohs: "Voice Oohs"
        case .synthVoice: "Synth Voice"
        case .orchestraHit: "Orchestra Hit"
        case .trumpet: "Trumpet"
        case .trombone: "Trombone"
        case .tuba: "Tuba"
        case .mutedTrumpet: "Muted Trumpet"
        case .frenchHorn: "French Horn"
        case .brassSection: "Brass Section"
        case .synthBrass1: "Synth Brass 1"
        case .synthBrass2: "Synth Brass 2"
        case .sopranoSax: "Soprano Sax"
        case .altoSax: "Alto Sax"
        case .tenorSax: "Tenor Sax"
        case .baritoneSax: "Baritone Sax"
        case .oboe: "Oboe"
        case .englishHorn: "English Horn"
        case .bassoon: "Bassoon"
        case .clarinet: "Clarinet"
        case .piccolo: "Piccolo"
        case .flute: "Flute"
        case .recorder: "Recorder"
        case .panFlute: "Pan Flute"
        case .blownBottle: "Blown Bottle"
        case .shakuhachi: "Shakuhachi"
        case .whistle: "Whistle"
        case .ocarina: "Ocarina"
        case .lead1Square: "Lead 1 (Square)"
        case .lead2Sawtooth: "Lead 2 (Sawtooth)"
        case .lead3Calliope: "Lead 3 (Calliope)"
        case .lead4Chiff: "Lead 4 (Chiff)"
        case .lead5Charang: "Lead 5 (Charang)"
        case .lead6Voice: "Lead 6 (Voice)"
        case .lead7Fifths: "Lead 7 (Fifths)"
        case .lead8BassLead: "Lead 8 (Bass + Lead)"
        case .pad1NewAge: "Pad 1 (New Age)"
        case .pad2Warm: "Pad 2 (Warm)"
        case .pad3Polysynth: "Pad 3 (Polysynth)"
        case .pad4Choir: "Pad 4 (Choir)"
        case .pad5Bowed: "Pad 5 (Bowed)"
        case .pad6Metallic: "Pad 6 (Metallic)"
        case .pad7Halo: "Pad 7 (Halo)"
        case .pad8Sweep: "Pad 8 (Sweep)"
        case .fx1Rain: "FX 1 (Rain)"
        case .fx2Soundtrack: "FX 2 (Soundtrack)"
        case .fx3Crystal: "FX 3 (Crystal)"
        case .fx4Atmosphere: "FX 4 (Atmosphere)"
        case .fx5Brightness: "FX 5 (Brightness)"
        case .fx6Goblins: "FX 6 (Goblins)"
        case .fx7Echoes: "FX 7 (Echoes)"
        case .fx8SciFi: "FX 8 (Sci-Fi)"
        case .sitar: "Sitar"
        case .banjo: "Banjo"
        case .shamisen: "Shamisen"
        case .koto: "Koto"
        case .kalimba: "Kalimba"
        case .bagpipe: "Bagpipe"
        case .fiddle: "Fiddle"
        case .shanai: "Shanai"
        case .tinkleBell: "Tinkle Bell"
        case .agogo: "Agogo"
        case .steelDrums: "Steel Drums"
        case .woodblock: "Woodblock"
        case .taikoDrum: "Taiko Drum"
        case .melodicTom: "Melodic Tom"
        case .synthDrum: "Synth Drum"
        case .reverseCymbal: "Reverse Cymbal"
        case .guitarFretNoise: "Guitar Fret Noise"
        case .breathNoise: "Breath Noise"
        case .seashore: "Seashore"
        case .birdTweet: "Bird Tweet"
        case .telephoneRing: "Telephone Ring"
        case .helicopter: "Helicopter"
        case .applause: "Applause"
        case .gunshot: "Gunshot"
        }
    }

    /// Instruments grouped by GM category, for use in picker UIs.
    static var groupedByCategory: [(category: GMCategory, instruments: [GuideToneInstrument])] {
        GMCategory.allCases.map { category in
            (category, allCases.filter { $0.category == category })
        }
    }
}
