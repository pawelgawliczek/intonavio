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
   - **Song Library** — Grid of user's songs (thumbnail, title, status badge). "Add Song" button.
   - **Exercises** — Horizontal scrollable categories (Scales, Arpeggios, Intervals, Vibrato, Breathing). Pre-built exercises ship with app; community-shared exercises available via browse/search.

4. **Add Song Sheet** — YouTube URL input, validation, submit. Shows processing progress after submission.
5. **Exercise Browser** — Browse/search community exercises, filter by category/difficulty.

### Practice

6. **Song Practice** — Full-screen, toggleable layout between two modes:
   - **Lyrics-focused**: Video ~65%, pitch graph ~35%
   - **Pitch-focused**: Video ~25% (small strip), pitch graph ~75%
   - Swipe or tap button to toggle between layouts
   - **Controls overlay**: Play/pause, A-B loop markers, speed slider (0.25x–2x), stem mode selector (Original / Vocals / Instrumental / All Stems), transpose picker (musical intervals from -2 octaves to +2 octaves)

7. **Exercise Practice** — Same pitch graph as song practice but no video. Shows exercise name, target notes as reference, and tempo/metronome guide.

### Pitch Graph Component (shared by views 6 & 7)

- Piano roll style (like Sing & See reference): piano keys on Y-axis, scrolling time on X-axis
- **3 visualization modes** (user toggles via segmented control):
  - **Target Zones + Colored Line**: Reference pitch as semi-transparent bands, user's live pitch as a continuous line colored by accuracy (green ±10¢, yellow-green ±25¢, yellow ±50¢, red >50¢)
  - **Two Distinct Lines**: Reference as thin dashed neutral line, user's pitch as bold colored line (same color scheme)
  - **Target Zones + Glowing Trail**: Reference as bands, user's pitch as animated glowing trail with intensity based on accuracy
- Current note name displayed large (left side), with cents deviation indicator
- Scrolling window: ~4s past + 4s future visible

### Sessions (Tab 2)

8. **Session History** — List of past practice sessions (date, song/exercise name, duration, score)
9. **Session Detail** — Replay pitch graph (scrubable), score breakdown, loop points used, speed used

### Settings (Tab 3)

10. **Settings** — Account management, audio input selection, pitch sensitivity, theme (dark/light)
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
│ ▶ LoopA LoopB 0.8x Stems T │
│      [controls bar]         │
└─────────────────────────────┘
```

**Pitch-focused mode:**

```
┌─────────────────────────────┐
│  Small video strip    ~25%  │
├─────────────────────────────┤
│                             │
│   Piano Roll Pitch Graph    │
│                             │
│   [ref bands + user line]   │
│   Current note: C4  +5¢    │
│          ~75%               │
│                             │
├─────────────────────────────┤
│ ▶ LoopA LoopB 0.8x Stems T │
│      [controls bar]         │
└─────────────────────────────┘
```

### Pitch Visualization Modes (toggle via segmented control on graph)

| Mode         | Reference Display              | User Display                                 | Feel                |
| ------------ | ------------------------------ | -------------------------------------------- | ------------------- |
| Zones + Line | Semi-transparent colored bands | Solid colored line (accuracy colors)         | Clean, analytical   |
| Two Lines    | Thin dashed gray line          | Bold colored line                            | Direct comparison   |
| Zones + Glow | Semi-transparent bands         | Glowing animated trail, intensity = accuracy | Engaging, game-like |

### Accuracy Color Scale

- **Green**: ±10 cents (excellent)
- **Yellow-green**: ±25 cents (good)
- **Yellow**: ±50 cents (fair)
- **Red**: >50 cents (off pitch)

---

## Verification

- Wireframe each view before implementation
- Prototype the toggleable layout with dummy data to validate feel
- Test pitch graph rendering at 43 FPS with simultaneous video playback (performance critical)
- Validate A-B loop controls are reachable in both layout modes
- Test all 3 pitch visualization modes with real microphone input
