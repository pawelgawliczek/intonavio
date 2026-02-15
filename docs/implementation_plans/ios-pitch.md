# Phase 5: iOS Pitch — Implementation Plan

## Context

Phase 4 (iOS Core) is complete — the app has authentication, song library, YouTube playback, A-B looping, and stem playback. The practice screen has an explicit "Coming in Phase 5" placeholder where the pitch graph goes. Sessions currently save with `overallScore: 0` and `pitchLog: []`.

This phase adds real-time pitch detection, a piano roll visualization with 3 modes, cents-based scoring, and exercise practice — completing the core singing practice experience.

## Decisions

- **YIN detector**: Port from validated spike (`spikes/spike-a/PitchSpike/`)
- **Rendering**: SwiftUI Canvas (GPU-accelerated via Core Graphics, sufficient for 2D at 60fps, much simpler than Metal)
- **Pitch data download**: Trigger when song becomes READY during polling (not on practice open)
- **Exercises**: Client-side pitch generation from bundled note definitions (backend exercise CRUD deferred)
- **Session replay**: Deferred — live practice + scoring only
- **Scope**: Both Song Practice and Exercise Practice

---

## Sub-Phase 5.1: Backend — Pitch Data Presigned URL

Add `GET /songs/:songId/pitch/url` returning a presigned R2 URL for the pitch reference JSON. Follows the existing stem URL pattern.

### Create

| File                                       | LOC | Purpose                                                            |
| ------------------------------------------ | --- | ------------------------------------------------------------------ |
| `apps/api/src/pitch/pitch.module.ts`       | ~12 | NestJS module                                                      |
| `apps/api/src/pitch/pitch.controller.ts`   | ~25 | Single endpoint, reuse `JwtAuthGuard`, `ParseCuidPipe`             |
| `apps/api/src/pitch/pitch.service.ts`      | ~40 | Query PitchData by songId, call `StorageService.getPresignedUrl()` |
| `apps/api/src/pitch/pitch.service.spec.ts` | ~80 | Unit tests                                                         |

### Modify

| File                         | Change                       |
| ---------------------------- | ---------------------------- |
| `apps/api/src/app.module.ts` | Add `PitchModule` to imports |

### Tests

- Returns presigned URL when PitchData exists for songId
- Throws 404 when PitchData not found
- Reuses `PresignedUrlResponse` DTO from stems module

---

## Sub-Phase 5.2: Port YIN Detector + Build PitchDetector Service

Port the spike's YIN algorithm and build a `PitchDetector` service that captures microphone input via a separate `AVAudioEngine` (coexists with StemPlayer).

### Create

| File                                    | LOC  | Purpose                                                                                                                                                   |
| --------------------------------------- | ---- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Audio/Pitch/PitchTypes.swift`          | ~55  | `PitchResult`, `PitchConstants`, `PitchPoint`, `NoteInfo` — port from spike                                                                               |
| `Audio/Pitch/NoteMapper.swift`          | ~60  | `frequencyToMidi`, `midiToFrequency`, `centsDeviation`, `centsBetween`, `noteInfo` — port from spike                                                      |
| `Audio/Pitch/YINDetector.swift`         | ~165 | 5-step YIN with Accelerate vDSP, parabolic interpolation — port from spike as-is                                                                          |
| `Audio/Pitch/PitchDetector.swift`       | ~140 | `@Observable` service: mic engine, ring buffer, installTap, dispatches `PitchResult` to main thread                                                       |
| `Audio/Pitch/AudioSessionManager.swift` | ~60  | Centralized `AVAudioSession` config for `.playAndRecord` + `.voiceChat` (AEC enabled). Both StemPlayer and PitchDetector use this. Handles interruptions. |

### Key constants (from spike, validated — updated in implementation)

- `analysisSize = 2048`, `hopSize = 256`, `sampleRate = 44100`
- `yinThreshold = 0.10`, `confidenceThreshold = 0.85` (raised from 0.80 to reduce false detections after AEC)
- `minFrequency = 80 Hz`, `maxFrequency = 1100 Hz`
- `rmsNoiseFloor = 0.01` (~-40 dB, RMS gate via `vDSP_rmsqv` from Accelerate)
- `maxMidiJump = 12.0` (reject >1 octave jumps within 50ms)
- `jumpTimeWindow = 0.05` seconds
- Detection rate: ~172/sec, latency: ~46ms, YIN processing: <0.5ms
- Audio session mode: `.voiceChat` (enables iOS AEC for speaker bleed removal)

### Modify

| File                     | Change                                 |
| ------------------------ | -------------------------------------- |
| `Utilities/Logger.swift` | Add `static let pitch` logger category |

### Tests (95% branch coverage required on YIN + NoteMapper)

- 440Hz sine -> detect ~440Hz (within ±1 Hz)
- 261.63Hz sine -> detect ~261.63Hz
- Silence -> return nil
- Noise -> nil or low confidence
- `centsBetween(440, 440)` == 0
- `centsBetween(440, 466.16)` == 100
- `centsBetween(440, 220)` == -1200
- `frequencyToMidi(440)` == 69.0
- Division-by-zero edge cases

---

## Sub-Phase 5.3: Reference Pitch Management

Download, cache, and query reference pitch data. Generate exercise pitch client-side.

### Create

| File                                       | LOC  | Purpose                                                                                                                                                                                                                   |
| ------------------------------------------ | ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Audio/Pitch/ReferencePitchFrame.swift`    | ~55  | `ReferencePitchFrame` and `ReferencePitchData` Codable structs matching pYIN worker output. Includes `rms` field and `isAudible` computed property (RMS >= 0.02 threshold) for artifact filtering.                        |
| `Audio/Pitch/PitchDataDownloader.swift`    | ~80  | Downloads pitch JSON from R2 via presigned URL, caches to `~/Library/Caches/pitch/{songId}/reference.json`. Provides `clearAllCache()` for manual cache invalidation via Settings.                                        |
| `Audio/Pitch/ReferencePitchStore.swift`    | ~100 | Loads frames, provides O(1) lookup by time (direct index: `time / hopDuration`), range queries for piano roll. Filters low-RMS frames from MIDI range computation. Provides `midiRange(from:to:)` for loop recalibration. |
| `Audio/Pitch/ExercisePitchGenerator.swift` | ~90  | Generates `ReferencePitchData` from `[ExerciseNote]` + tempo. Handles sustained notes, vibrato modulation, rests.                                                                                                         |
| `Audio/Pitch/ExerciseDefinitions.swift`    | ~90  | Bundled exercise data: major/minor scales, arpeggios, sustained notes, vibrato exercises. Uses `ExerciseNote` structs.                                                                                                    |

### Modify

| File                                      | Change                                                                                                         |
| ----------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `Networking/APIEndpoint.swift`            | Add `case pitchDownloadURL(songId: String)` with path `/songs/{songId}/pitch/url`                              |
| `Networking/APIClientProtocol.swift`      | Add `func pitchDownloadURL(songId:) async throws -> PresignedURLResponse`                                      |
| `Networking/APIClient.swift`              | Add implementation                                                                                             |
| `Networking/MockAPIClient.swift`          | Add mock                                                                                                       |
| `Features/Library/LibraryViewModel.swift` | In `refreshSong()`: when song transitions to READY and has pitchData, trigger `PitchDataDownloader.download()` |

### Pitch data download trigger

When `LibraryViewModel.refreshSong()` detects a song just became READY (status changed from processing to READY), call `PitchDataDownloader` to download and cache the pitch JSON. This happens during the polling loop, so pitch data is ready before the user opens practice.

### Tests (95% branch coverage on ExercisePitchGenerator)

- `ReferencePitchStore`: load valid JSON, `frame(at:)` returns correct frame, out-of-range returns nil, `frames(from:to:)` correct slice
- `ExercisePitchGenerator`: sustained C4 at 80 BPM -> correct frame count + Hz, vibrato oscillates within range, rests produce unvoiced frames
- `PitchDataDownloader`: cache hit returns local URL, cache miss calls API

---

## Sub-Phase 5.4: Scoring Engine

Pure-logic module comparing detected pitch against reference, accumulating session statistics.

### Create

| File                                | LOC  | Purpose                                                                                                                                      |
| ----------------------------------- | ---- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `Audio/Pitch/DifficultyLevel.swift` | ~100 | Enum: `beginner`/`intermediate`/`advanced`. Cent thresholds, point values, zone definitions. Stored via `@AppStorage("difficultyLevel")`.    |
| `Audio/Pitch/PitchAccuracy.swift`   | ~50  | Enum: `excellent`/`good`/`fair`/`poor`/`unvoiced`. `classify(cents:difficulty:)` and `points(difficulty:)` use `DifficultyLevel` thresholds. |
| `Audio/Pitch/ScoringEngine.swift`   | ~120 | `@Observable`. Evaluates each detection against reference with transpose offset. Accumulates `pitchLog: [PitchLogEntry]` and `overallScore`. |

### ScoringEngine.evaluate() algorithm

1. Look up reference frame at `playbackTime` via `ReferencePitchStore.frame(at:)`
2. If reference is unvoiced -> skip (no scoring during rests)
3. Apply transpose: `adjustedRefHz = refHz × 2^(transposeSemitones / 12)`
4. If detected is unvoiced -> record as unvoiced, don't score
5. `cents = 1200 * log2(detectedHz / adjustedRefHz)`
6. Classify via `PitchAccuracy.classify(cents:difficulty:)` (defaults to current difficulty)
7. `totalPoints += accuracy.points()`, increment `voicedReferenceFrames`
8. `overallScore = totalPoints / voicedReferenceFrames * 100` (guard division by zero)
9. Append `PitchLogEntry` to `pitchLog` (with `adjustedRefHz`, not original)

### Tests (95% branch coverage)

- Exact match -> 0 cents, excellent
- Boundary tests per difficulty level (Beginner: ±150/300/450, Intermediate: ±25/50/75, Advanced: ±25/40/60)
- Points per difficulty (excellent 100 all; good 75/60/50; fair 40/25/20)
- Unvoiced reference -> skip
- All unvoiced -> score remains 0 (no division by zero)
- Mixed accuracies -> correct weighted score

---

## Sub-Phase 5.5: Piano Roll Visualization

SwiftUI Canvas piano roll with 3 visualization modes.

### Create

| File                                                   | LOC  | Purpose                                                                                                                                   |
| ------------------------------------------------------ | ---- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `Features/Practice/PianoRoll/VisualizationMode.swift`  | ~25  | `enum VisualizationMode: zonesLine, twoLines, zonesGlow`                                                                                  |
| `Features/Practice/PianoRoll/DetectedPitchPoint.swift` | ~20  | Struct: `time`, `midi`, `accuracy`, `cents`                                                                                               |
| `Features/Practice/PianoRoll/PianoRollView.swift`      | ~140 | Container: mode selector (segmented control), piano key labels, canvas, current note display                                              |
| `Features/Practice/PianoRoll/PianoRollCanvas.swift`    | ~150 | SwiftUI `Canvas`: draws grid, reference pitch, detected pitch based on mode                                                               |
| `Features/Practice/PianoRoll/PianoRollRenderer.swift`  | ~140 | Static drawing helpers: `drawReferenceZones`, `drawReferenceLine` (both accept `transposeOffset`), `drawDetectedLine`, `drawDetectedGlow` |
| `Features/Practice/PianoRoll/CurrentNoteView.swift`    | ~50  | Large note name (e.g. "C4") + cents deviation indicator (e.g. "+5¢"), color-coded by accuracy                                             |

### Visualization modes (per docs/16-ui-views-flow.md)

1. **Zones + Line**: Reference as semi-transparent bands (1 semitone height), detected as solid colored line
2. **Two Lines**: Reference as thin dashed gray line, detected as bold colored line
3. **Zones + Glow**: Reference as bands, detected as glowing animated trail (intensity = accuracy)

### Rendering specs

- Y-axis: MIDI notes, dynamic range centered on current note ±12 semitones (1 octave)
- X-axis: 8-second scrolling window (4s past + 4s future)
- Colors: green (excellent), yellow (good), orange (fair), gray (poor) — zone widths scale with difficulty level
- Target: 43+ FPS with video playing simultaneously

### Tests

- SwiftUI previews for all 3 modes with mock data
- Preview with: normal data, wide range, silence gaps, single note
- Manual FPS check using debug overlay (sub-phase 5.8)

---

## Sub-Phase 5.6: Song Practice Integration

Wire everything into PracticeViewModel and SongPracticeView. Add toggleable layout.

### Create

| File                                              | LOC  | Purpose                                                                                                                                                               |
| ------------------------------------------------- | ---- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Features/Practice/PracticeViewModel+Pitch.swift` | ~130 | Extension: `startPitchDetection()`, `stopPitchDetection()`, `downloadPitchData()`, `handleDetectedPitch()` (with jump filter + transpose), `setTranspose()`           |
| `Features/Practice/PracticeViewModel+Loop.swift`  | ~80  | Extracted A-B loop check task + per-pass scoring: `captureLoopScore()`, `ScoreChange` enum. Captures score at loop boundary, computes improvement delta, shows toast. |
| `Features/Practice/LoopScoreToastView.swift`      | ~55  | Toast overlay showing loop pass score (%) and improvement delta (green/red arrow). Auto-dismisses after 2 seconds.                                                    |
| `Features/Practice/PracticeLayoutMode.swift`      | ~15  | `enum PracticeLayoutMode: lyricsFocused (65/35), pitchFocused (25/75)`                                                                                                |
| `Audio/Pitch/TransposeInterval.swift`             | ~42  | `enum TransposeInterval`: 13 musical intervals from -2 oct to +2 oct, with labels                                                                                     |

### Modify

| File                                                  | Change                                                                                                                                                                                                                                                                                                                                                                           |
| ----------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Features/Practice/PracticeViewModel.swift`           | Add properties: `pitchDetector`, `referenceStore`, `scoringEngine`, `detectedPoints`, `isPitchReady`, `layoutMode`, `visualizationMode`, `transposeSemitones`, `lastDetectedMidi`, `lastDetectionTimestamp`. Computed: `transposedMidiMin/Max` (loop-aware). Loop scoring state: `loopScores`, `lastLoopScore`, `loopScoreImprovement`, `isShowingLoopScore`, `loopMidiMin/Max`. |
| `Features/Practice/SongPracticeView.swift`            | Replace `pitchPlaceholder` with `PianoRollView`. Pass `transposedMidiMin/Max` and `transposeSemitones`. Add layout toggle button. Video height driven by `layoutMode`. Transparent overlay blocks YouTube player touch events. `LoopScoreToastView` overlay.                                                                                                                     |
| `Features/Practice/ExercisePracticeView.swift`        | Pass `transposeSemitones: 0` to PianoRollView (exercises don't use transpose).                                                                                                                                                                                                                                                                                                   |
| `Features/Practice/PracticeViewModel+Audio.swift`     | Modify `saveSessionIfNeeded()` to use `scoringEngine.pitchLog` and `scoringEngine.finalScore` instead of hardcoded `0` and `[]`.                                                                                                                                                                                                                                                 |
| `Features/Practice/ControlsBarView.swift`             | Add layout toggle, visualization mode picker, and transpose picker. Speed selector removed from UI.                                                                                                                                                                                                                                                                              |
| `Features/Practice/PianoRoll/PianoRollView.swift`     | Accept `transposeSemitones: Int`, pass to canvas.                                                                                                                                                                                                                                                                                                                                |
| `Features/Practice/PianoRoll/PianoRollCanvas.swift`   | Accept `transposeSemitones: Int`, compute `Float` offset, pass to reference renderer calls only.                                                                                                                                                                                                                                                                                 |
| `Features/Practice/PianoRoll/PianoRollRenderer.swift` | `drawReferenceZones` and `drawReferenceLine` accept `transposeOffset: Float = 0`, shift MIDI notes. Detected pitch draws are unaffected.                                                                                                                                                                                                                                         |
| `Audio/Pitch/ScoringEngine.swift`                     | Add `transposeSemitones: Int = 0`, apply `refHz × 2^(semitones/12)` in `evaluate()`.                                                                                                                                                                                                                                                                                             |
| `Audio/Pitch/PitchDetector.swift`                     | Add `import Accelerate`, RMS noise gate via `vDSP_rmsqv` before YIN.                                                                                                                                                                                                                                                                                                             |
| `Audio/Pitch/PitchTypes.swift`                        | Raise `confidenceThreshold` to 0.85, add `rmsNoiseFloor`, `maxMidiJump`, `jumpTimeWindow` constants.                                                                                                                                                                                                                                                                             |
| `Audio/Pitch/AudioSessionManager.swift`               | Change mode from `.default` to `.voiceChat` for AEC.                                                                                                                                                                                                                                                                                                                             |

### Integration flow

1. `configure()`: if song has pitchData, set `isPitchReady` (data already cached from LibraryViewModel)
2. `play()`: if isPitchReady and in stem mode, start PitchDetector
3. Each detection -> `handleDetectedPitch()` -> evaluate via ScoringEngine -> append to `detectedPoints`
4. PianoRollView renders from `referenceStore.frames(from:to:)` + `detectedPoints`
5. `saveSessionIfNeeded()`: use `scoringEngine.pitchLog` and `scoringEngine.finalScore`

### Tests

- Verify pitch detection starts/stops with playback
- Verify layout toggle switches 65/35 <-> 25/75
- Verify session save includes non-empty pitchLog when pitch was active
- Verify clean teardown on view disappear

---

## Sub-Phase 5.7: Exercise Practice

Exercise practice reuses piano roll, scoring, and pitch detector. New: ExercisePracticeViewModel, metronome, updated UI.

### Create

| File                                                | LOC  | Purpose                                                                                                                                  |
| --------------------------------------------------- | ---- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `Features/Practice/ExercisePracticeViewModel.swift` | ~150 | `@Observable`. Generates reference from exercise definition, manages playback timer (no YouTube), coordinates pitch detection + scoring. |
| `Audio/MetronomeTick.swift`                         | ~60  | Plays click at BPM using short sine burst on AVAudioPlayerNode.                                                                          |

### Modify

| File                                           | Change                                                                                                                                        |
| ---------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `Features/Practice/ExercisePracticeView.swift` | Rewrite from placeholder. Layout: exercise header (name, tempo, key) + PianoRollView + controls (play/pause, restart, tempo) + score display. |
| `Features/Library/ExerciseSectionView.swift`   | Use `ExerciseDefinitions` for data source instead of hardcoded mock.                                                                          |
| `Features/Library/ExerciseBrowserView.swift`   | Wire exercise rows to `NavigationLink` -> `ExercisePracticeView`. Remove "Coming soon" labels.                                                |

### Exercise practice flow

1. `prepare()`: call `ExercisePitchGenerator.generate()` with exercise notes + tempo
2. Load result into `ReferencePitchStore`
3. `play()`: start metronome at BPM, start playback timer advancing `currentTime`, start PitchDetector
4. Piano roll shows reference notes and detected pitch, same 3 visualization modes
5. When exercise ends (currentTime >= duration): stop, show final score

---

## Sub-Phase 5.8: Debug Tools + Polish

### Create

| File                                                  | LOC | Purpose                                                                                                       |
| ----------------------------------------------------- | --- | ------------------------------------------------------------------------------------------------------------- |
| `Features/Practice/PianoRoll/PitchDebugOverlay.swift` | ~80 | `#if DEBUG`. Shows: raw Hz, confidence, MIDI, latency stats, FPS counter, reference frame, scoring breakdown. |
| `Audio/Pitch/PitchRecorder.swift`                     | ~70 | `#if DEBUG`. Records raw mic + detected pitches to disk for offline analysis.                                 |

### Modify

| File                                    | Change                                                                                            |
| --------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `Features/Settings/DeveloperView.swift` | Add "Pitch Debug" section: overlay toggle, recording toggle, export button.                       |
| `Features/Settings/SettingsView.swift`  | Add "Data" section with "Clear Pitch Cache" button calling `PitchDataDownloader.clearAllCache()`. |

### Test files to create

| File                                                     | LOC  | Covers                                          |
| -------------------------------------------------------- | ---- | ----------------------------------------------- |
| `IntonavioTests/Audio/YINDetectorTests.swift`            | ~120 | Sine waves, silence, noise, edge cases          |
| `IntonavioTests/Audio/NoteMapperTests.swift`             | ~80  | Frequency/MIDI/cents conversions                |
| `IntonavioTests/Audio/ScoringEngineTests.swift`          | ~120 | All accuracy thresholds, boundaries, edge cases |
| `IntonavioTests/Audio/ExercisePitchGeneratorTests.swift` | ~100 | Sustained, vibrato, rests, tempo scaling        |
| `IntonavioTests/Audio/ReferencePitchStoreTests.swift`    | ~80  | Load, lookup, range queries                     |

---

## Dependency Graph

```
5.1 Backend Pitch URL ─────┐
                            ├── 5.3 Reference Pitch ──┐
5.2 YIN Detector ──────────┤                          ├── 5.5 Piano Roll ──┬── 5.6 Song Practice
                            └── 5.4 Scoring Engine ───┘                    │
                                                                           ├── 5.7 Exercise Practice
                                                                           │
                                                                           └── 5.8 Debug + Tests
```

5.1 and 5.2 can be built in parallel. 5.6 and 5.7 can be built in parallel after 5.5.

---

## New files summary: ~27 files, ~2,500 LOC (includes TransposeInterval + PracticeViewModel+Loop)

## Modified files: ~18 files (includes echo cancellation, transpose threading, Xcode project)

## Test files: 5 new test files, ~550 LOC (includes 5 transpose scoring tests)

---

## Verification

After all sub-phases:

1. **Unit tests**: Run full test suite — all 129 tests pass (58 existing + 71 new pitch tests including 5 transpose scoring tests)
2. **Build**: `xcodebuild build` — zero errors, warnings only
3. **Manual — echo cancellation**: Play song via YouTube → stay silent → no detected pitch dots appear (AEC removes speaker audio)
4. **Manual — noise gate**: Stay silent while song plays → no detected pitch dots (RMS gate filters silence after AEC)
5. **Manual — song practice**: Open a READY song → switch to instrumental mode → sing → see live pitch on piano roll with color-coded accuracy → Done → session saves with score > 0 and non-empty pitchLog
6. **Manual — exercise practice**: Library → Exercises → Major Scale C4 → Practice → metronome ticks → sing notes → piano roll shows reference + detected → final score displayed
7. **Manual — transpose**: Open transpose menu → select "+1 oct" → reference zones shift up 12 semitones, detected voice stays in place, score reflects comparison to transposed reference
8. **Manual — transpose reset**: Navigate away → return to practice → transpose is 0
9. **Layout toggle**: In song practice, toggle between lyrics-focused (65/35) and pitch-focused (25/75) — video and piano roll resize correctly
10. **Visualization modes**: Cycle through Zones+Line, Two Lines, Zones+Glow — all render correctly
11. **Performance**: Practice with video + stems + pitch detection — no dropped frames, no audio glitches
12. **Edge cases**: Song without pitchData → piano roll shows "not available" state, practice still works for looping/stems
