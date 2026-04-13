import Foundation

/// Folds a `PitchEditScript` onto a base frame array. Refine in separate file.
enum PitchEditApplier {
    static func apply(
        base: [ReferencePitchFrame],
        hopDuration: Double,
        otherVariants: [StemSource: [ReferencePitchFrame]],
        script: PitchEditScript
    ) -> [ReferencePitchFrame] {
        guard hopDuration > 0 else { return base }
        var frames = base
        for op in script.operations {
            let (lo, hi) = frameRange(op.range, hopDuration: hopDuration, count: frames.count)
            guard lo < hi else { continue }
            switch op {
            case .useVariant(_, _, let source):
                applyUseVariant(&frames, lo: lo, hi: hi, source: source,
                                others: otherVariants, hopDuration: hopDuration)
            case .despike(_, _, let maxJumpSemitones):
                applyDespike(&frames, lo: lo, hi: hi, maxJumpSemitones: maxJumpSemitones)
            case .mute:
                applyMute(&frames, lo: lo, hi: hi)
            case .shiftOctave(_, _, let octaves):
                applyShiftOctave(&frames, lo: lo, hi: hi, octaves: octaves)
            case .shiftSemitones(_, _, let semitones):
                applyShiftSemitones(&frames, lo: lo, hi: hi, semitones: semitones)
            case .addPassage(_, _, let opFrames, let mode):
                applyAddPassage(&frames, lo: lo, hi: hi, opFrames: opFrames,
                                mode: mode, hopDuration: hopDuration)
            case .fillGaps:
                applyFillGaps(&frames, lo: lo, hi: hi)
            case .refine:
                applyRefine(&frames, lo: lo, hi: hi, base: base)
            }
        }
        return frames
    }

    // MARK: - Helpers

    private static func frameRange(
        _ range: TimeRange,
        hopDuration: Double,
        count: Int
    ) -> (Int, Int) {
        let lo = max(0, min(count, Int((range.start / hopDuration).rounded())))
        let hi = max(0, min(count, Int((range.end / hopDuration).rounded())))
        return (lo, hi)
    }

    private static func makeFrame(
        index: Int,
        hopDuration: Double,
        hz: Double?,
        voiced: Bool,
        midi: Double?,
        rms: Double?
    ) -> ReferencePitchFrame {
        ReferencePitchFrame(
            time: Double(index) * hopDuration,
            frequency: hz,
            isVoiced: voiced,
            midiNote: midi,
            rms: rms
        )
    }

    private static func applyUseVariant(
        _ frames: inout [ReferencePitchFrame],
        lo: Int,
        hi: Int,
        source: StemSource,
        others: [StemSource: [ReferencePitchFrame]],
        hopDuration: Double
    ) {
        guard let other = others[source] else { return }
        for i in lo..<hi where i < other.count {
            let f = other[i]
            frames[i] = makeFrame(
                index: i,
                hopDuration: hopDuration,
                hz: f.frequency,
                voiced: f.isVoiced,
                midi: f.midiNote,
                rms: f.rms
            )
        }
    }

    private static func applyDespike(
        _ frames: inout [ReferencePitchFrame],
        lo: Int,
        hi: Int,
        maxJumpSemitones: Double
    ) {
        let snapshot = frames
        for i in lo..<hi {
            let f = snapshot[i]
            guard f.isVoiced, let hz = f.frequency, hz > 0 else { continue }
            guard
                let (jHz, _) = nearestVoiced(snapshot, from: i, step: -1),
                let (kHz, _) = nearestVoiced(snapshot, from: i, step: 1)
            else { continue }
            let dj = abs(12.0 * log2(hz / jHz))
            let dk = abs(12.0 * log2(hz / kHz))
            if dj > maxJumpSemitones && dk > maxJumpSemitones {
                let newHz = (jHz * kHz).squareRoot()
                let newMidi = 69.0 + 12.0 * log2(newHz / 440.0)
                frames[i] = ReferencePitchFrame(
                    time: f.time,
                    frequency: newHz,
                    isVoiced: true,
                    midiNote: newMidi,
                    rms: f.rms
                )
            }
        }
    }

    private static func nearestVoiced(
        _ frames: [ReferencePitchFrame],
        from index: Int,
        step: Int
    ) -> (Double, Int)? {
        var i = index + step
        while i >= 0 && i < frames.count {
            let f = frames[i]
            if f.isVoiced, let hz = f.frequency, hz > 0 {
                return (hz, i)
            }
            i += step
        }
        return nil
    }

    private static func applyMute(
        _ frames: inout [ReferencePitchFrame],
        lo: Int,
        hi: Int
    ) {
        for i in lo..<hi {
            let f = frames[i]
            frames[i] = ReferencePitchFrame(
                time: f.time,
                frequency: nil,
                isVoiced: false,
                midiNote: nil,
                rms: f.rms
            )
        }
    }

    private static func applyShiftOctave(
        _ frames: inout [ReferencePitchFrame],
        lo: Int,
        hi: Int,
        octaves: Int
    ) {
        let factor = pow(2.0, Double(octaves))
        let midiDelta = Double(12 * octaves)
        for i in lo..<hi {
            let f = frames[i]
            guard f.isVoiced, let hz = f.frequency else { continue }
            frames[i] = ReferencePitchFrame(
                time: f.time,
                frequency: hz * factor,
                isVoiced: true,
                midiNote: f.midiNote.map { $0 + midiDelta },
                rms: f.rms
            )
        }
    }

    private static func applyShiftSemitones(
        _ frames: inout [ReferencePitchFrame],
        lo: Int,
        hi: Int,
        semitones: Int
    ) {
        let factor = pow(2.0, Double(semitones) / 12.0)
        let midiDelta = Double(semitones)
        for i in lo..<hi {
            let f = frames[i]
            guard f.isVoiced, let hz = f.frequency else { continue }
            frames[i] = ReferencePitchFrame(
                time: f.time,
                frequency: hz * factor,
                isVoiced: true,
                midiNote: f.midiNote.map { $0 + midiDelta },
                rms: f.rms
            )
        }
    }

    private static func applyAddPassage(
        _ frames: inout [ReferencePitchFrame],
        lo: Int,
        hi: Int,
        opFrames: [ReferencePitchFrame],
        mode: DrawMode,
        hopDuration: Double
    ) {
        guard !opFrames.isEmpty else { return }
        for i in lo..<hi {
            let targetTime = Double(i) * hopDuration
            guard let src = nearestOpFrame(opFrames, targetTime: targetTime) else { continue }
            let existing = frames[i]
            if mode == .additive && existing.isVoiced { continue }
            frames[i] = ReferencePitchFrame(
                time: targetTime,
                frequency: src.frequency,
                isVoiced: src.isVoiced,
                midiNote: src.midiNote,
                rms: src.rms
            )
        }
    }

    private static func nearestOpFrame(
        _ opFrames: [ReferencePitchFrame],
        targetTime: Double
    ) -> ReferencePitchFrame? {
        var best: ReferencePitchFrame?
        var bestDelta = Double.infinity
        for f in opFrames {
            let d = abs(f.time - targetTime)
            if d < bestDelta {
                bestDelta = d
                best = f
            }
        }
        return best
    }

    /// Visible = voiced + audible RMS + has frequency. Used by Fill Gaps and Refine.
    static func isVisible(_ f: ReferencePitchFrame) -> Bool {
        f.isVoiced && f.isAudible && f.frequency != nil
    }

    private static func nearestVisible(
        _ frames: [ReferencePitchFrame],
        from index: Int,
        step: Int
    ) -> (Double, Double, Int)? {
        var i = index + step
        while i >= 0 && i < frames.count {
            let f = frames[i]
            if isVisible(f), let hz = f.frequency, let midi = f.midiNote {
                return (hz, midi, i)
            }
            i += step
        }
        return nil
    }

    private static func applyFillGaps(
        _ frames: inout [ReferencePitchFrame],
        lo: Int,
        hi: Int
    ) {
        // Two-pass: first collect all gap runs within [lo, hi),
        // then interpolate each using anchors from the full array.
        // A "gap" is any frame that is not visible (unvoiced OR low RMS).
        var gaps: [(start: Int, end: Int)] = []
        var i = lo
        while i < hi {
            if !isVisible(frames[i]) {
                let gapStart = i
                while i < hi && !isVisible(frames[i]) { i += 1 }
                gaps.append((start: gapStart, end: i))
            } else {
                i += 1
            }
        }
        for gap in gaps {
            guard let (leftHz, leftMidi, leftIdx) = nearestVisible(frames, from: gap.start, step: -1)
            else { continue }
            let searchBase = max(0, gap.end - 1)
            guard let (rightHz, rightMidi, rightIdx) = nearestVisible(frames, from: searchBase, step: 1)
            else { continue }
            guard rightIdx > leftIdx else { continue }
            let span = Double(rightIdx - leftIdx)
            // Use the average RMS of the two anchors for filled frames
            let anchorRms = ((frames[leftIdx].rms ?? 0.05) + (frames[rightIdx].rms ?? 0.05)) / 2
            for j in gap.start..<gap.end {
                let t = Double(j - leftIdx) / span
                let hz = leftHz + (rightHz - leftHz) * t
                let midi = leftMidi + (rightMidi - leftMidi) * t
                frames[j] = ReferencePitchFrame(
                    time: frames[j].time,
                    frequency: hz,
                    isVoiced: true,
                    midiNote: midi,
                    rms: anchorRms
                )
            }
        }
    }
}
