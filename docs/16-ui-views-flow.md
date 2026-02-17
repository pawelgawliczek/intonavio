# Intonavio — UI Views & Flow

## Context

Defining all views, navigation, and layout decisions for the Intonavio singing practice app before implementation begins. This covers iOS (primary), with web and macOS following the same structure later.

---

## Views (11 total)

### Auth

1. **Sign In** — Apple / Google / Email options
2. **Sign Up** — Email registration form

### Home (Tab 1: Library)

3. **Home** — Two sections stacked vertically:
   - **Song Library** — Grid of user's songs (thumbnail, title, artist, status badge). "Add Song" button.
   - **Exercises** — Horizontal scrollable categories (Scales, Arpeggios, Intervals, Vibrato, Breathing). Pre-built exercises ship with app; community-shared exercises available via browse/search.

4. **Add Song Sheet** — YouTube URL input, validation, submit. Shows processing progress after submission.
5. **Exercise Browser** — Browse/search community exercises, filter by category/difficulty.

### Practice

6. **Song Practice** — Full-screen, toggleable layout between two modes:
   - **Lyrics-focused**: Video ~65%, pitch graph ~35%
   - **Pitch-focused**: Video ~25% (small strip), pitch graph ~75%
   - Swipe or tap button to toggle between layouts
   - **Controls overlay**: Play/pause, A-B loop markers, stem mode selector (Original / Vocals / Instrumental), transpose picker (musical intervals from -2 octaves to +2 octaves)
   - **Loop score toast**: When A-B loop is active, a toast overlay appears after each pass showing the score percentage and improvement delta (green arrow up / red arrow down). Auto-dismisses after 2 seconds.
   - **Progress sheet** (toolbar button, chart icon): Shows overall best score and per-phrase score breakdown. Tapping a phrase row sets up an A-B loop around that phrase (with breathing room), dismisses the sheet, and seeks to the phrase start — without auto-playing. User presses play to start the loop.
   - **YouTube video**: Non-interactive — covered by a transparent touch-blocking overlay. All playback controlled via controls bar.
   - **Piano roll**: Interactive — touch to pause, swipe to scrub with momentum, long-press to loop a phrase (see Piano Roll Touch Gestures below).

7. **Exercise Practice** — Same pitch graph as song practice but no video. Shows exercise name, target notes as reference, and tempo/metronome guide.

### Pitch Graph Component (shared by views 6 & 7)

- Piano roll style (like Sing & See reference): piano keys on Y-axis, scrolling time on X-axis
- **Interactive gestures**: Touch to pause, swipe to scrub with momentum, long-press to loop a phrase (see Piano Roll Touch Gestures below)
- **3 visualization modes** (user toggles via segmented control):
  - **Target Zones + Colored Line**: Reference pitch as semi-transparent bands, user's live pitch as a continuous line colored by accuracy (green ±10¢, yellow-green ±25¢, yellow ±50¢, red >50¢)
  - **Two Distinct Lines**: Reference as thin dashed neutral line, user's pitch as bold colored line (same color scheme)
  - **Target Zones + Glowing Trail**: Reference as bands, user's pitch as animated glowing trail with intensity based on accuracy
- Current note name displayed large (left side), with cents deviation indicator
- Scrolling window: ~4s past + 4s future visible
- **Browsing mode**: When scrubbing, the playhead switches to dashed style and a dimmed secondary line shows actual playback position

### Sessions (Tab 2)

8. **Session History** — List of past practice sessions (date, song/exercise name, duration, score)
9. **Session Detail** — Replay pitch graph (scrubable), score breakdown, loop points used, speed used

### Settings (Tab 3)

10. **Settings** — Account management, audio input selection, theme (dark/light), pitch data cache management (clear & re-download)
11. **Profile / Community** — User's shared exercises, stats, linked accounts

---

## Navigation Structure (iOS)

```
Tab Bar (3 tabs)
├── Library (Home)
│   ├── Song Library grid
│   │   ├── Add Song (sheet)
│   │   └── Song → Song Practice (full-screen push)
│   └── Exercises section
│       ├── Exercise → Exercise Practice (full-screen push)
│       └── Browse Community (push)
├── Sessions
│   └── Session → Session Detail (push)
└── Settings
    └── Profile / Community (push)
```

---

## Primary User Flows

### New User

```
Sign In → Home (empty library) → Add Song → Processing... → Song ready → Tap song → Song Practice → Session saved → Sessions tab
```

### Returning Singer

```
Home → Tap song → Song Practice (toggle to pitch-focused) → Set A-B loop → Adjust speed → Practice → Done → Score shown → Session saved
```

### Exercise Warmup

```
Home → Scroll to Exercises → Tap scale exercise → Exercise Practice → Sing along to target notes → Score → Session saved
```

### Browse Community Exercises

```
Home → Exercises → Browse Community → Search/filter → Add to library → Practice
```

---

## Practice Screen Detail

### Song Practice Layout (Toggleable)

**Lyrics-focused mode:**

```
┌─────────────────────────────┐
│                             │
│     YouTube Video           │
│     (lyrics visible)        │
│          ~65%               │
│                             │
├─────────────────────────────┤
│  Piano Roll Pitch Graph     │
│  [ref bands + user line]    │
│          ~35%               │
├─────────────────────────────┤
│ ▶  LoopA LoopB  Stems  T    │
│      [controls bar]         │
└─────────────────────────────┘
```

**Pitch-focused mode:**

```
┌─────────────────────────────┐
│  Small video strip    ~25%  │
│  [touch-blocked overlay]    │
├─────────────────────────────┤
│                             │
│   Piano Roll Pitch Graph    │
│   [Loop Score Toast: 78%↑5] │
│   [ref bands + user line]   │
│   Current note: C4  +5¢    │
│          ~75%               │
│                             │
├─────────────────────────────┤
│ ▶  LoopA LoopB  Stems  T    │
│      [controls bar]         │
└─────────────────────────────┘
```

### Piano Roll Touch Gestures

The piano roll responds to touch gestures for interactive browsing:

| Gesture                   | Behavior                                                                                                                                                                             |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Touch and hold**        | Pauses playback immediately. Lifting the finger (short tap) keeps playback paused at the current position.                                                                           |
| **Drag (swipe)**          | Enters browsing mode — the displayed time decouples from playback. The graph scrolls with the finger. A dashed playhead and dimmed secondary line show the actual playback position. |
| **Lift after drag**       | Starts momentum scrolling with deceleration (friction 0.95/frame at 60fps). When momentum stops, playback auto-resumes from the browsed position.                                    |
| **Touch during momentum** | Stops the momentum engine and re-enters the touch-and-hold state (pauses playback).                                                                                                  |
| **Long press (~1s)**      | Finds the phrase at the touch position (or nearest phrase within ±2s) and sets up an A-B loop around it. Haptic feedback on iOS.                                                     |

**Browsing mode state machine:**

```
IDLE → [touch] → TOUCHING (pause, start 1s timer)
  TOUCHING → [drag > 10pt] → DRAGGING (cancel timer, scroll graph)
  TOUCHING → [1s elapsed] → LONG PRESS (find phrase → loop)
  TOUCHING → [lift < 1s] → IDLE (stay paused)
  DRAGGING → [lift] → MOMENTUM (decelerate → auto-resume)
  MOMENTUM → [decay stops] → seek + play → IDLE
  MOMENTUM → [touch] → TOUCHING (stop engine, re-pause)
```

### Pitch Visualization Modes (toggle via segmented control on graph)

| Mode         | Reference Display              | User Display                                 | Feel                |
| ------------ | ------------------------------ | -------------------------------------------- | ------------------- |
| Zones + Line | Semi-transparent colored bands | Solid colored line (accuracy colors)         | Clean, analytical   |
| Two Lines    | Thin dashed gray line          | Bold colored line                            | Direct comparison   |
| Zones + Glow | Semi-transparent bands         | Glowing animated trail, intensity = accuracy | Engaging, game-like |

### Accuracy Color Scale

Colors are consistent across all difficulty levels; the cent thresholds change per level (see `docs/06-realtime-pitch.md`).

- **Green**: Excellent (within tightest zone)
- **Yellow**: Good (middle zone)
- **Orange**: Fair (outer zone)
- **Gray**: Poor (outside all zones)

Difficulty is selected in Settings → Difficulty (Beginner / Intermediate / Advanced). Zone bands on the piano roll visually widen or narrow to reflect the selected level.

---

## Verification

- Wireframe each view before implementation
- Prototype the toggleable layout with dummy data to validate feel
- Test pitch graph rendering at 43 FPS with simultaneous video playback (performance critical)
- Validate A-B loop controls are reachable in both layout modes
- Test all 3 pitch visualization modes with real microphone input
- Test piano roll gestures: touch → playback pauses; swipe → graph scrolls with momentum → playback resumes from new position; long-press ~1s → loop created around nearest phrase
- Verify browsing edge cases: touch during momentum stops scrolling, song boundary clamping, play pressed while browsing seeks to browsed position
