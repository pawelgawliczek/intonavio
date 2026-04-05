# Intonavio — Onboarding

## Purpose

First-launch onboarding that gets the user to the "wow moment" — seeing their pitch on the piano roll against a real song — as fast as possible. The flow is linear (no skipping individual screens), but concise enough to complete in under 60 seconds.

## When It Shows

- **First launch only.** Gated by a `hasCompletedOnboarding` flag in `UserDefaults` (set `true` on completion).
- Presented as a full-screen cover over `ContentView` after auth resolves (authenticated or not). Onboarding runs before sign-in — no account required to experience the wow moment.
- Users who sign in on a new device do **not** re-see onboarding (server-side `hasOnboarded` flag synced on first token exchange, written to local `UserDefaults` immediately).

## Screen Sequence

### Screen 1 — Welcome

```
┌─────────────────────────────┐
│                              │
│        [App Icon]            │
│                              │
│       Intonavio              │
│                              │
│  Sing along to any song.     │
│  See your pitch in real time.│
│  Get better, fast.           │
│                              │
│                              │
│       [ Get Started ]        │
│                              │
└─────────────────────────────┘
```

- App icon + name centered
- Three short value props
- Single "Get Started" CTA

### Screen 2 — Headphones

```
┌─────────────────────────────┐
│                              │
│      [Headphones icon]       │
│                              │
│   Plug in headphones with    │
│   a microphone               │
│                              │
│   Intonavio listens to your  │
│   voice while playing music. │
│   Without headphones, the    │
│   speaker audio bleeds into  │
│   the mic and ruins pitch    │
│   detection.                 │
│                              │
│   It still works without them, │
│   but headphones give you the │
│   best experience.            │
│                               │
│   Wired earbuds with a mic    │
│   work best. AirPods work     │
│   too — just avoid speakers.  │
│                              │
│       [ Continue ]           │
│                              │
└─────────────────────────────┘
```

**This is the most important screen in onboarding.** Without headphones, speaker output creates a feedback loop where the mic picks up the backing track instead of (or mixed with) the user's voice. The scoring becomes less accurate, the piano roll shows noise, and the first impression suffers. The app still functions without headphones — pitch detection works, just with degraded accuracy — but the experience is dramatically better with them.

**Design notes:**

- Icon: headphones with a small mic boom, or wired EarPods style
- Tone: direct and honest, not scary. Explain _why_, not just _what_.
- Do **not** gate progress on headphone detection — some Bluetooth headphones report as speakers, and false negatives would block legitimate users. This is an advisory screen.
- If the system audio route is already headphones (checked via `AVAudioSession.currentRoute`), show a green checkmark: "Headphones detected" — reinforces that they're set up correctly.
- If the route is speaker, show an orange hint: "No headphones detected" — but still allow "Continue".

### Screen 3 — Microphone Permission

```
┌─────────────────────────────┐
│                              │
│     [Microphone icon]        │
│                              │
│   Allow microphone access    │
│                              │
│   Intonavio uses your mic    │
│   to detect your pitch       │
│   while you sing. Nothing    │
│   is recorded or sent        │
│   anywhere.                  │
│                              │
│       [ Allow ]              │
│                              │
└─────────────────────────────┘
```

- Tapping "Allow" triggers the system `AVAudioSession.requestRecordPermission()` dialog.
- If the user denies: show inline message "Microphone access is required for pitch detection. You can enable it in Settings." with a "Open Settings" link and a "Continue without mic" option (library browsing still works, but practice is disabled).
- Privacy reassurance: audio is processed on-device in real time and never stored or transmitted.

### Screen 4 — Quick Pitch Test

```
┌─────────────────────────────┐
│                              │
│   Sing any note — hold it    │
│   for a moment               │
│                              │
│  ┌───────────────────────┐   │
│  │                       │   │
│  │   [ Live piano roll ] │   │
│  │   User's pitch line   │   │
│  │   appears in real time│   │
│  │                       │   │
│  └───────────────────────┘   │
│                              │
│   Current note: --           │
│                              │
│   (updates live as user      │
│    sings or hums)            │
│                              │
│       [ Continue ]           │
│                              │
└─────────────────────────────┘
```

**This is the wow moment.** The user sings or hums and immediately sees their pitch rendered on the piano roll. No song, no reference — just raw "my voice moves this line" feedback.

- Start the `AudioEngine` + `PitchDetector` when this screen appears.
- Show a simplified piano roll (no reference line, just the user's pitch).
- Display the detected note name below the graph (e.g., "A3", "C#4").
- "Continue" button is always enabled — no minimum sing duration required.
- If mic permission was denied on the previous screen, skip this screen entirely.

### Screen 5 — Add Your First Song

```
┌─────────────────────────────┐
│                              │
│     [Music note icon]        │
│                              │
│   Pick a song to practice    │
│                              │
│   Search for any song on     │
│   YouTube, or choose from    │
│   the catalog.               │
│                              │
│   [ Browse Catalog ]         │
│   [ Search YouTube ]         │
│                              │
│        Skip for now          │
│                              │
└─────────────────────────────┘
```

- "Browse Catalog" opens the catalog picker (pre-processed songs, instant start).
- "Search YouTube" opens the Add Song sheet search tab.
- "Skip for now" dismisses onboarding and lands on the empty Home screen.
- After a song is added (or skipped), onboarding completes: set `hasCompletedOnboarding = true` and dismiss the full-screen cover.

## Flow Diagram

```
Launch
  │
  ▼
Auth resolved
  │
  ├── hasCompletedOnboarding == true → Home
  │
  └── hasCompletedOnboarding == false
        │
        ▼
   Screen 1: Welcome
        │
        ▼
   Screen 2: Headphones (advisory, checks audio route)
        │
        ▼
   Screen 3: Mic Permission (system dialog)
        │
        ├── Granted ──────────────────┐
        │                             │
        └── Denied → show fallback    │
              │                       │
              ▼                       ▼
        (skip pitch test)    Screen 4: Pitch Test (wow moment)
              │                       │
              ▼                       ▼
        Screen 5: Add First Song
              │
              ▼
        hasCompletedOnboarding = true → Home
```

## Implementation Notes

### State Management

- `OnboardingView`: a full-screen cover with a `TabView(.page)` style pager (swipe disabled — forward-only via buttons).
- `OnboardingViewModel` (`@Observable`): tracks `currentStep`, manages permission requests, audio engine lifecycle for pitch test.
- `hasCompletedOnboarding` stored in `UserDefaults` (local) and synced to server on next API call (so new-device installs skip it).

### Audio Route Detection (Screen 2)

```swift
let route = AVAudioSession.sharedInstance().currentRoute
let hasHeadphones = route.outputs.contains { output in
    [.headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE]
        .contains(output.portType)
}
```

Show "Headphones detected" (green) or "No headphones detected" (orange) based on this check. Update in real time via `AVAudioSession.routeChangeNotification` so plugging in headphones while on this screen updates the indicator live.

### Pitch Test (Screen 4)

- Reuse the existing `AudioEngine` and `PitchDetector` — no separate audio setup.
- Render a simplified `PianoRollView` with no reference data (user line only).
- Stop the audio engine when leaving this screen (`onDisappear`).

### Analytics Events

| Event                            | Payload                                         |
| -------------------------------- | ----------------------------------------------- |
| `onboarding_started`             | —                                               |
| `onboarding_headphones_detected` | `{detected: bool}`                              |
| `onboarding_mic_permission`      | `{granted: bool}`                               |
| `onboarding_pitch_test_sung`     | `{note_detected: bool}`                         |
| `onboarding_song_added`          | `{source: "catalog" \| "youtube" \| "skipped"}` |
| `onboarding_completed`           | `{duration_seconds: int}`                       |

### Accessibility

- All screens support VoiceOver with descriptive labels.
- Pitch test screen: announce detected note name via `AccessibilityNotification.Announcement`.
- Headphone detection status announced on change.
- Minimum tap target 44x44pt on all buttons.

## Design Principles

1. **Speed over thoroughness** — 5 screens, under 60 seconds. Don't explain every feature.
2. **Headphones first** — this is the single biggest factor in first-session quality. Make it unmissable.
3. **Show, don't tell** — the pitch test is worth more than any explanation of what the app does.
4. **No account wall** — onboarding runs before sign-in. Reduce friction to the wow moment.
5. **Graceful degradation** — if mic is denied, skip the pitch test. If no headphones, warn but don't block. The app still works, just worse.
