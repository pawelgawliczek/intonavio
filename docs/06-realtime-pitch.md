# Intonavio — Real-Time Pitch Detection

## Overview

Real-time pitch detection is the core interactive feature. The app captures the singer's voice via microphone, detects the fundamental frequency (F0), compares it against the reference pitch at the current playback time, and provides visual feedback on a piano roll.

---

## iOS Audio Graph

Stem playback and microphone input share a single `AudioEngine` instance. Voice processing (AEC) on the input node uses the output graph to cancel stem audio from the mic signal.

```mermaid
graph LR
    subgraph SharedAudioEngine
        Mic[Microphone<br/>inputNode VP/AEC] --> Tap[installTap<br/>bufferSize: 1024<br/>format: 44.1kHz mono]
        Players[PlayerNodes<br/>vocals/other/full] --> Mixer[stemMixer] --> TP[TimePitch] --> Out[mainMixer<br/>→ output]
    end
    Tap --> YIN[YIN Pitch Detector<br/>Swift implementation]
    YIN --> Freq[Detected Frequency<br/>Hz + confidence]
    Freq --> Compare[Compare vs Reference<br/>at current time T]
    Compare --> Cents[Cents Deviation]
    Cents --> UI[Piano Roll UI<br/>SwiftUI Canvas]
```

### iOS Implementation Notes

- A shared **AudioEngine** wraps a single `AVAudioEngine` with voice processing (AEC) enabled on the input node
- **StemPlayer**, **PitchDetector**, and **MetronomeTick** all receive the shared engine via init — none creates its own
- **installTap** with buffer size 1024 at 44.1kHz gives callbacks every ~23ms
- **YIN algorithm** runs synchronously in the tap callback (audio thread)
- Detected pitch is dispatched to main thread for UI update
- The reference pitch array is binary-searched by timestamp for O(log n) lookup
- All audio (including "original" mode) routes through stem playback — YouTube audio is not used
- **Audio route changes** (AirPods connect/disconnect) trigger a full stem re-sync — stops stems, re-applies mode volumes, restarts from current YouTube time
- **TimePitch latency** (~125ms) is compensated in `StemPlayer.play(from:)` by scheduling frames ahead, so audio output aligns with the requested time

### Audio Session: Echo Cancellation

The audio session uses `.measurement` mode with voice processing enabled separately on the input node. Because stem playback and mic input share one engine, VPIO sees the stem output going to speakers and cancels it from the mic input. Without this, the microphone picks up the song's melody and the detected pitch line follows the music rather than the user's voice.

```swift
AVAudioSession.sharedInstance().setCategory(
    .playAndRecord,
    mode: .measurement,  // VP enabled separately on inputNode for AEC
    options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
)
```

### Pre-Detection Filtering

Three filters prevent false detections:

1. **RMS noise gate**: Before running YIN, compute RMS via `vDSP_rmsqv` (Accelerate framework). If RMS < 0.01 (~-40 dB), skip detection entirely. This filters true silence after AEC removes the music.
2. **Confidence threshold**: Set to 0.85 (stricter than the typical 0.80). Rejects low-confidence detections from residual noise.
3. **MIDI jump filter**: Reject detections where MIDI jumps >12 semitones (1 octave) within 50ms of the previous detection. This catches spurious octave jumps from harmonic confusion.

```swift
// Pseudocode for iOS pitch detection (uses shared AudioEngine)
let sharedEngine = AudioEngine()
try sharedEngine.prepare()  // Enable VP before attaching nodes
// ... StemPlayer attaches playback nodes here ...
try sharedEngine.start()

let format = sharedEngine.inputFormat  // Read after VP is enabled

sharedEngine.installInputTap(bufferSize: 1024, format: format) { buffer, time in
    let samples = Array(UnsafeBufferPointer(
        start: buffer.floatChannelData?[0],
        count: Int(buffer.frameLength)
    ))

    // RMS noise gate
    var rms: Float = 0
    vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
    guard rms >= 0.01 else { return }

    let (frequency, confidence) = yinDetect(samples, sampleRate: format.sampleRate)

    if confidence > 0.85 {
        DispatchQueue.main.async {
            self.updatePianoRoll(detectedHz: frequency, at: currentPlaybackTime)
        }
    }
}
```

---

## Web Audio Graph

```mermaid
graph LR
    Mic[Microphone<br/>MediaStream] --> Source[MediaStreamSource<br/>AudioContext]
    Source --> Worklet[AudioWorkletNode<br/>YIN Processor]
    Worklet -->|postMessage| Main[Main Thread<br/>frequency + confidence]
    Main --> Compare[Compare vs Reference]
    Compare --> UI[Piano Roll<br/>Canvas / SVG]
```

### Web Implementation Notes

- **AudioWorklet** runs pitch detection off the main thread for smooth UI
- The worklet processor accumulates samples until it has 1024, then runs YIN
- Results are sent via `postMessage` to the main thread
- Reference pitch data is pre-loaded as a typed array for fast lookup

---

## Pitch Comparison Flow

```mermaid
flowchart TD
    A[Mic buffer arrives<br/>1024 samples] --> A1{RMS > 0.01?}
    A1 -->|No| D[Skip — below<br/>noise floor]
    A1 -->|Yes| B[Run YIN algorithm]
    B --> C{Confidence > 0.85?}
    C -->|No| D2[Mark frame as<br/>unvoiced / silence]
    C -->|Yes| C2{MIDI jump<br/>> 12 semitones<br/>in < 50ms?}
    C2 -->|Yes| D3[Reject — spurious<br/>octave jump]
    C2 -->|No| E[Get detected frequency<br/>in Hz]

    E --> F[Get current playback<br/>time T seconds]
    F --> G[Binary search reference<br/>pitch at time T]
    G --> G2[Apply transpose offset<br/>refHz × 2^semitones/12]
    G2 --> H{Reference frame<br/>voiced?}

    H -->|No| I[Skip comparison<br/>no reference note]
    H -->|Yes| J[Compute cents deviation<br/>1200 × log2 detected/adjustedRef]

    J --> K{Classify accuracy}
    K -->|within excellent zone| L[Excellent<br/>green]
    K -->|within good zone| M[Good<br/>yellow]
    K -->|within fair zone| N[Fair<br/>orange]
    K -->|outside all zones| O[Poor<br/>gray]

    L --> P[Update piano roll<br/>with color-coded dot]
    M --> P
    N --> P
    O --> P
```

---

## Scoring Thresholds (Difficulty Levels)

Thresholds and point rewards are controlled by `DifficultyLevel` (stored in UserDefaults). The user selects a level in Settings. Default is **Beginner**.

| Category  | Beginner             | Intermediate        | Advanced            | Color  |
| --------- | -------------------- | ------------------- | ------------------- | ------ |
| Excellent | ±150 cents → 100 pts | ±25 cents → 100 pts | ±25 cents → 100 pts | Green  |
| Good      | ±300 cents → 75 pts  | ±50 cents → 60 pts  | ±40 cents → 50 pts  | Yellow |
| Fair      | ±450 cents → 40 pts  | ±75 cents → 25 pts  | ±60 cents → 20 pts  | Orange |
| Poor      | >450 cents → 0 pts   | >75 cents → 0 pts   | >60 cents → 0 pts   | Gray   |

Piano roll zone bands visually reflect the selected difficulty (wider bands = easier). Best scores are tracked per difficulty level via a `difficulty` field on `ScoreRecord` (SwiftData).

**Cents formula (with transpose):**

```
adjustedRefHz = referenceHz × 2^(transposeSemitones / 12)
cents = 1200 × log₂(detectedHz / adjustedRefHz)
```

When `transposeSemitones = 0`, this reduces to the standard formula. One semitone = 100 cents.

**Overall session score:**

```
score = (sum of frame scores / number of voiced reference frames) × 100
```

Only frames where the reference vocal is voiced and audible (`rms >= 0.02`) are counted — silence, breaths, instrumental sections, and low-energy stem separation artifacts are excluded.

---

## Reference Pitch Transpose

Users can shift the reference pitch graph up or down by musical intervals to practice in a different vocal register. This is a **visual + scoring shift only** — no audio processing is applied to the playback.

### Available Intervals

| Interval         | Semitones | Label  |
| ---------------- | --------- | ------ |
| 2 octaves down   | -24       | -2 oct |
| Octave down      | -12       | -1 oct |
| Fifth down       | -7        | -5th   |
| Fourth down      | -5        | -4th   |
| Major third down | -4        | -M3    |
| Minor third down | -3        | -m3    |
| Unison (default) | 0         | 0      |
| Minor third up   | +3        | +m3    |
| Major third up   | +4        | +M3    |
| Fourth up        | +5        | +4th   |
| Fifth up         | +7        | +5th   |
| Octave up        | +12       | +1 oct |
| 2 octaves up     | +24       | +2 oct |

### Where Transpose Applies

| Component              | Transposed? | Why                                                    |
| ---------------------- | ----------- | ------------------------------------------------------ |
| Reference zones/lines  | Yes         | MIDI notes shifted by `transposeOffset` on piano roll  |
| Reference Hz (scoring) | Yes         | `refHz × 2^(semitones/12)` before cents calculation    |
| Detected pitch display | No          | User's voice shown at actual position                  |
| MIDI range (Y-axis)    | Yes         | Piano roll range shifts to keep transposed ref visible |
| Audio playback         | No          | No pitch-shifting of stems or YouTube audio            |

### Implementation

- `TransposeInterval` enum (`Audio/Pitch/TransposeInterval.swift`) holds all intervals with `rawValue` as semitone offset
- `PracticeViewModel.transposeSemitones` drives both scoring and rendering
- `ScoringEngine.transposeSemitones` shifts reference before `centsBetween()` calculation
- `PianoRollRenderer.transposeOffset` shifts reference draw positions (zones and lines)
- Transpose resets to 0 when navigating away from practice

---

## Piano Roll Visualization

The piano roll is a scrolling 2D display shared by both song practice and exercise practice views (see `docs/16-ui-views-flow.md`):

- **Y-axis**: Piano keys / MIDI note numbers (pitch), labeled with note names (C4, D4, E4...)
- **X-axis**: Time, scrolling left as playback progresses
- **Current note**: Displayed large on the left side, with cents deviation indicator

### Visualization Modes

The user toggles between 3 modes via a segmented control on the pitch graph:

| Mode             | Reference Display              | User Display                                 | Feel                |
| ---------------- | ------------------------------ | -------------------------------------------- | ------------------- |
| **Zones + Line** | Semi-transparent colored bands | Solid colored line (accuracy colors)         | Clean, analytical   |
| **Two Lines**    | Thin dashed gray line          | Bold colored line (same color scheme)        | Direct comparison   |
| **Zones + Glow** | Semi-transparent bands         | Glowing animated trail, intensity = accuracy | Engaging, game-like |

### Rendering Specs

| Property             | Value                                                                    |
| -------------------- | ------------------------------------------------------------------------ |
| Visible time window  | 8 seconds (4s past + 4s future)                                          |
| Y-axis range         | Dynamic, centered on current note ±1 octave                              |
| Update rate          | ~43 FPS (matching audio callback rate)                                   |
| Reference bar height | 1 semitone                                                               |
| Dot size             | 4pt                                                                      |
| Transpose offset     | Applied to reference draws only; detected pitch stays at actual position |

### Interactive Browsing Mode

The piano roll supports touch gestures that decouple the displayed time from playback (see `docs/16-ui-views-flow.md` — Piano Roll Touch Gestures for the full state machine).

**Architecture:**

- `PianoRollGestureState` (`@MainActor @Observable`) tracks browsing mode: `isBrowsing`, `browseOffset`, `browseAnchorTime`, and `InteractionPhase` (idle, touching, dragging, momentum, longPressing)
- `PianoRollMomentumEngine` (`@MainActor @Observable`) provides timer-based deceleration at 60fps (friction 0.95/frame, stops below 0.01 threshold)
- `PianoRollGestureOverlay` is a transparent overlay with `DragGesture(minimumDistance: 0)` that classifies gestures and drives state transitions
- Gesture state lives as `@State` on `PianoRollSection` (not on `PracticeViewModel`) — the ViewModel only receives final commands: `pause()`, `seek(to:)`, `play()`, `setupPhraseLoop(phraseIndex:)`

**Visual indicators during browsing:**

| Element            | Normal                    | Browsing                                   |
| ------------------ | ------------------------- | ------------------------------------------ |
| Playhead (center)  | Solid white line          | Dashed white line (increased opacity)      |
| Playback position  | Not shown                 | Dimmed dashed vertical line at actual time |
| Canvas time window | Centered on playback time | Centered on browsed time (anchor + offset) |

**Position-to-time conversion:**

```
touchTime = centerTime - windowDuration/2 + (x / canvasWidth) × windowDuration
dragOffset = -(translation.width / canvasWidth) × windowDuration
```

**Long press phrase lookup:** `referenceStore.phrase(at: touchTime)` finds the phrase under the finger. If no exact match, the nearest phrase within ±2 seconds is selected. Haptic feedback on iOS (light impact on touch, medium on loop creation, rigid on no phrase found).

---

## Buffer Size vs Latency Tradeoffs

| Buffer Size | Duration @ 44.1kHz | Frequency Resolution | Latency  | Use Case                               |
| ----------- | ------------------ | -------------------- | -------- | -------------------------------------- |
| 512         | 11.6ms             | ~86 Hz               | Very low | Too imprecise below ~170 Hz            |
| **1024**    | **23.2ms**         | **~43 Hz**           | **Low**  | **Best balance for singing (default)** |
| 2048        | 46.4ms             | ~21 Hz               | Medium   | Better for bass voices                 |
| 4096        | 92.9ms             | ~10 Hz               | High     | Too sluggish for real-time feedback    |

**Why 1024?**

- 23ms latency is imperceptible for visual feedback
- 43 Hz resolution covers notes down to ~F1, well below typical singing range
- YIN at 1024 samples completes in <1ms on modern hardware

---

## YIN Algorithm Summary

YIN is an autocorrelation-based pitch detection algorithm optimized for monophonic audio (single voice).

**Steps:**

1. Compute the difference function (autocorrelation variant)
2. Cumulative mean normalized difference
3. Absolute threshold (τ where d'(τ) < threshold)
4. Parabolic interpolation for sub-sample accuracy
5. Convert lag to frequency: `f = sampleRate / lag`

**Why YIN over alternatives?**

| Algorithm    | Pros                                       | Cons                               | Used In              |
| ------------ | ------------------------------------------ | ---------------------------------- | -------------------- |
| **YIN**      | Fast, accurate for monophonic, low latency | Requires tuning threshold          | iOS & Web real-time  |
| **pYIN**     | Probabilistic, handles vibrato better      | Slower (batch processing)          | Server-side analysis |
| **FFT peak** | Simple                                     | Poor resolution at low frequencies | Not used             |
| **CREPE**    | Neural net, very accurate                  | Too slow for real-time on mobile   | Not used             |

The iOS and Web clients use classic YIN for real-time detection. The Python worker uses pYIN (via librosa) for offline reference pitch extraction where accuracy matters more than speed.

---

## Reference Pitch Sources

The piano roll and scoring pipeline consume the same `{t, hz, midi, voiced, rms}` frame array regardless of whether the reference comes from a song or an exercise. The only difference is how the reference is produced.

```mermaid
flowchart TD
    subgraph Song Path
        A[Vocal Stem MP3] --> B[Python Worker<br/>pYIN via librosa]
        B --> C[reference.json]
    end

    subgraph Exercise Path
        D[Exercise Definition<br/>notes JSON] --> E[Pitch Data Generator<br/>deterministic expansion]
        E --> F[reference.json]
    end

    C --> G[Same frame format<br/>t hz midi voiced]
    F --> G
    G --> H[Piano Roll + Scoring<br/>identical pipeline]
```

### Exercise Pitch Data Generation

The generator expands an exercise note definition (see [[04-data-models]]) into frame-by-frame pitch data at the same 11.6ms hop interval used by pYIN extraction.

**Algorithm:**

1. Read exercise `notes` array and `tempo` (BPM)
2. Convert beat durations to seconds: `seconds = beats × 60 / tempo`
3. For each note, generate frames at 11.6ms intervals:
   - **Sustained note**: all frames at `baseHz = 440 × 2^((midi - 69) / 12)`
   - **With vibrato**: modulate each frame: `hz = baseHz × 2^(vibratoCents × sin(2π × rateHz × t) / 1200)`
   - **Rest period**: generate unvoiced frames (`hz: null, voiced: false`)
4. Write the complete frame array as the same JSON format used by songs
5. Upload to R2 at `pitch/{exerciseId}/reference.json`

**Example: C4 sustained for 2 beats at 80 BPM with vibrato**

- Duration: 2 × 60/80 = 1.5 seconds = ~129 frames
- Base frequency: 261.63 Hz (MIDI 60)
- Each frame: `hz = 261.63 × 2^(30 × sin(2π × 5.5 × t) / 1200)`

The result is a smooth pitch curve that oscillates ±30 cents around C4 at 5.5 Hz — the singer must match this curve to score well on vibrato exercises.

### Why This Works

The client never needs to know whether it's practicing a song or an exercise. It loads a reference pitch JSON, plays back (stems for songs, metronome/guide tone for exercises), captures the singer's pitch, and compares frame by frame. The piano roll renders identically in both cases.

---

## Reference Pitch RMS Filtering

Vocal stems from stem separation contain low-energy residual noise from other instruments. The pYIN algorithm marks these as "voiced" because they have detectable pitch, but they are artifacts — not real vocal signal. The `rms` field in each pitch frame enables the client to filter them out.

### How It Works

1. **Worker side**: `librosa.feature.rms()` computes per-frame energy alongside `librosa.pyin()` using the same hop length. Values are included in the JSON output.
2. **Client side**: Frames with `rms < 0.02` are considered "inaudible" and excluded from:
   - Piano roll rendering (no reference zones/lines drawn for inaudible frames)
   - MIDI range computation (prevents artifacts from expanding the Y-axis range)
   - Scoring (inaudible reference frames are treated like unvoiced frames)

### Threshold Selection

The threshold of `0.02` was chosen empirically. In tested vocal stems, real vocal signal has RMS values > 0.05, while stem separation artifacts typically have RMS values in the range 0.0001–0.001.

### Pitch Data Caching

Pitch data is cached locally at `~/Library/Caches/pitch/{songId}/reference.json`. The cache persists across sessions. If pitch data is re-analyzed on the server (e.g., after a worker update), users can clear the cache via Settings > Data > "Clear Pitch Cache" to force a re-download.

---

## Loop Scoring

When an A-B loop is active, the scoring engine provides per-pass feedback to show improvement over repeated practice.

### Per-Pass Scoring Flow

1. User sets markers A and B → loop state becomes `.looping`
2. `ScoringEngine.reset()` clears accumulated scores for the new loop
3. Playback proceeds from A to B, scoring each detected pitch against the reference
4. When `currentTime >= B`, before seeking back to A:
   - Capture `scoringEngine.overallScore` as the pass score
   - Compare to the previous pass score → compute improvement (better/worse/same)
   - Reset the scoring engine for the next pass
   - Show a toast overlay with score and delta (auto-dismisses after 2 seconds)
5. Increment `loopCount` and seek back to A

### MIDI Range Recalibration

When a loop is activated, the piano roll's Y-axis range recalibrates to the looped section's pitch range (with ±3 semitone padding) instead of using the full song's range. This zooms in to show the relevant notes for the section being practiced. The range reverts to full-song when the loop is cleared.
