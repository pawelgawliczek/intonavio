# Phase 4: iOS Core — Implementation Plan

## Context

Phases 1–3 (Backend, Pitch Worker, Infrastructure) are complete. Two iOS spikes validated real-time pitch detection (Spike A) and YouTube WKWebView looping (Spike B). No production iOS project exists yet — this phase creates it from scratch.

Phase 4 delivers: authentication, song library, YouTube playback with A-B looping, stem playback via AVAudioEngine, and session history. It does **not** include pitch detection, piano roll, or scoring (those are Phase 5).

---

## Sub-Phases

### 4.1: Xcode Project Setup + Navigation Skeleton

Create the iOS project at `apps/ios/` with 3-tab navigation and stub views.

**Files to create:**

- `apps/ios/Intonavio/App/IntonavioApp.swift` — `@main` entry, `AVAudioSession` config (`.playAndRecord`, `.measurement`, `.defaultToSpeaker`), interruption handling
- `apps/ios/Intonavio/App/ContentView.swift` — `TabView` with 3 `NavigationStack` tabs (Library, Sessions, Settings); auth gate via `fullScreenCover`
- `apps/ios/Intonavio/App/AppState.swift` — `@Observable`: `isAuthenticated`, `selectedTab`
- Stub views (14 files) in `Features/{Auth,Library,Practice,Sessions,Settings}/` — each with `#Preview`
- `apps/ios/Intonavio/Utilities/Logger.swift` — `os.Logger` wrapper, replaces all `print()`
- `apps/ios/.swiftlint.yml` — strict config: `file_length: 300`, `function_body_length: 40`, `type_body_length: 200`, `cyclomatic_complexity: 10`, `nesting: 3`

**Verify:** App launches in simulator, 3 tabs visible, SwiftLint clean.

---

### 4.2: Networking Layer (APIClient + Codable Models)

Protocol-based API client with all models mirroring backend DTOs.

**Files to create:**

- `apps/ios/Intonavio/Networking/APIClientProtocol.swift` — methods for all endpoints (auth, songs, stems, sessions)
- `apps/ios/Intonavio/Networking/APIClient.swift` — `URLSession`-based implementation, auto token refresh on 401, debug request logging
- `apps/ios/Intonavio/Networking/APIError.swift` — `{ statusCode, error, message, traceId }` matching backend format
- `apps/ios/Intonavio/Networking/APIEndpoint.swift` — endpoint enum with path, method, body
- `apps/ios/Intonavio/Networking/TokenManager.swift` — Keychain read/write for JWT tokens via `Security` framework
- `apps/ios/Intonavio/Networking/MockAPIClient.swift` — fixture data for previews/tests
- `apps/ios/Intonavio/Networking/Models/AuthModels.swift` — `AuthResponse`, `AuthUser`, request DTOs
- `apps/ios/Intonavio/Networking/Models/SongModels.swift` — `SongResponse`, `StemResponse`, `PitchDataResponse`, `SongStatus` enum, `StemType` enum, `CreateSongRequest`
- `apps/ios/Intonavio/Networking/Models/SessionModels.swift` — `SessionResponse`, `SessionDetailResponse`, `CreateSessionRequest`, `PitchLogEntry`
- `apps/ios/Intonavio/Networking/Models/PaginatedResponse.swift` — generic `PaginatedResponse<T: Codable>` with `PaginationMeta`
- `apps/ios/IntonavioTests/Networking/APIClientTests.swift`
- `apps/ios/IntonavioTests/Networking/CodableModelTests.swift`

**API base URL:** from `Info.plist` build config (`API_BASE_URL`), defaulting to `http://localhost:3000/v1`

**Token refresh flow:** intercept 401 → call `POST /v1/auth/refresh` → retry original request once → if refresh fails, clear Keychain + set `isAuthenticated = false`

**Verify:** Unit tests decode fixture JSON into all models. MockAPIClient returns valid data.

---

### 4.3: Auth Module (Apple Sign In + Email)

**Files to create/modify:**

- `apps/ios/Intonavio/Features/Auth/AuthViewModel.swift` — `@Observable`: sign-in/up flows, error state
- `apps/ios/Intonavio/Features/Auth/SignInView.swift` — Apple Sign In button (`AuthenticationServices`), email login fields, sign-up link
- `apps/ios/Intonavio/Features/Auth/SignUpView.swift` — email, password, displayName form
- `apps/ios/Intonavio/Features/Auth/AppleSignInButton.swift` — wrapped `SignInWithAppleButton`
- Modify `AppState.swift` — check `TokenManager.hasValidTokens` on launch, background token refresh
- `apps/ios/IntonavioTests/Auth/AuthViewModelTests.swift`

**Backend auth endpoints available:**

- `POST /v1/auth/apple` — Apple Sign In (`identityToken`, `authorizationCode`, `fullName?`)
- `POST /v1/auth/register` — email registration (`email`, `password` min 8 chars, `displayName`)
- `POST /v1/auth/login` — email login (`email`, `password`)
- `POST /v1/auth/refresh` — token refresh (`refreshToken`)
- `DELETE /v1/auth/account` — account deletion (cascades all data)

All return `{ accessToken, refreshToken, user: { id, email, displayName } }`.

**Not yet in backend (out of scope for Phase 4):** forgot password, email verification, change password, change email, update displayName. These need backend endpoints first.

**Note:** Google Sign In deferred (requires GoogleSignIn SDK + web redirect). The protocol method exists; button shows "Coming soon".

**Auth restore on launch:** check Keychain for tokens → set `isAuthenticated` → background `refreshToken()` to verify validity.

**Verify:** Apple Sign In on device. Email register + login. Tokens persist across restarts. Sign out clears tokens.

---

### 4.4: Song Library + Add Song

**Files to create/modify:**

- `apps/ios/Intonavio/Features/Library/LibraryViewModel.swift` — `@Observable`: fetch songs, add song, poll processing status (every 3s via cancellable `Task`)
- `apps/ios/Intonavio/Features/Library/HomeView.swift` — `LazyVGrid` song grid (2 cols iPhone, 3 iPad) + exercises placeholder section
- `apps/ios/Intonavio/Features/Library/SongGridItemView.swift` — `AsyncImage` thumbnail, title, status badge
- `apps/ios/Intonavio/Features/Library/AddSongSheet.swift` — URL input, validation, submit (`POST /v1/songs`), processing progress
- `apps/ios/Intonavio/Features/Library/SongStatusBadge.swift` — colored badge per status
- `apps/ios/Intonavio/Utilities/YouTubeURLValidator.swift` — regex: `youtube.com/watch?v=`, `youtu.be/`, `/embed/`, `/shorts/`, `m.youtube.com`
- `apps/ios/IntonavioTests/Library/LibraryViewModelTests.swift`
- `apps/ios/IntonavioTests/Utilities/YouTubeURLValidatorTests.swift`

**Verify:** Library loads songs from API. Add Song creates and shows processing progress. Status badges update. Pull-to-refresh works. Tap song navigates to practice.

---

### 4.5: YouTube Player (Port from Spike B)

Port spike code from `spikes/spike-b/YouTubeSpike/YouTube/` into production structure. Wrap behind `VideoPlayerProtocol` for swappability.

**Spike files to port:**

- `spikes/spike-b/YouTubeSpike/YouTube/YouTubeBridge.swift` (77 lines) → `apps/ios/Intonavio/YouTube/YouTubeBridge.swift`
- `spikes/spike-b/YouTubeSpike/YouTube/YouTubeHTML.swift` (96 lines) → `apps/ios/Intonavio/YouTube/YouTubeHTML.swift`
- `spikes/spike-b/YouTubeSpike/YouTube/YouTubePlayerView.swift` (148 lines) → split into `YouTubePlayerView.swift` + `YouTubePlayerController.swift`
- `spikes/spike-b/YouTubeSpike/YouTube/YouTubeSchemeHandler.swift` (108 lines) → `apps/ios/Intonavio/YouTube/YouTubeLocalServer.swift`

**New files:**

- `apps/ios/Intonavio/YouTube/VideoPlayerProtocol.swift` — `play()`, `pause()`, `seek(to:)`, `setPlaybackRate(_:)`, `mute()`, `unmute()`, `currentTime`, `duration`, `isReady`
- `apps/ios/Intonavio/Features/Practice/SongPracticeView.swift` — basic layout: YouTube video + placeholder pitch area + controls bar
- `apps/ios/Intonavio/Features/Practice/PracticeViewModel.swift` — `@Observable`: playback state, video control

**Changes from spike:** replace `print()` with `AppLogger`, add `VideoPlayerProtocol` conformance, split files to stay under 300 lines.

**Verify:** Tap READY song → YouTube video loads and plays. Play/pause/seek/mute work via JS bridge.

---

### 4.6: A-B Loop Controls

Port loop UI from spike-b. Add speed control.

**Spike files to port:**

- `spikes/spike-b/YouTubeSpike/Views/LoopControlsView.swift` (132 lines)
- `spikes/spike-b/YouTubeSpike/Views/TimelineBarView.swift` (191 lines)
- `spikes/spike-b/YouTubeSpike/Views/PlaybackControlsView.swift` (107 lines)
- Loop state machine from `spikes/spike-b/YouTubeSpike/ViewModels/PlayerViewModel.swift`

**Files to create:**

- `apps/ios/Intonavio/Features/Practice/LoopControlsView.swift`
- `apps/ios/Intonavio/Features/Practice/TimelineBarView.swift`
- `apps/ios/Intonavio/Features/Practice/PlaybackControlsView.swift`
- `apps/ios/Intonavio/Features/Practice/ControlsBarView.swift`
- `apps/ios/Intonavio/Features/Practice/LoopState.swift` — enum: `idle`, `playing`, `settingA`, `settingAB`, `looping`, `paused`
- `apps/ios/Intonavio/Features/Practice/SpeedSelectorView.swift` — discrete steps: 0.25x, 0.5x, 0.75x, 1.0x, 1.25x, 1.5x, 2.0x
- Extend `PracticeViewModel.swift` with loop state machine + speed control

**Changes from spike:** replace `Timer.scheduledTimer` with cancellable `Task`-based loop check (50ms interval).

**Verify:** Set A/B markers, playback loops. Drag markers on timeline. Speed changes apply. Clear loop returns to normal playback.

---

### 4.7: Stem Playback (AVAudioEngine)

**Files to create:**

- `apps/ios/Intonavio/Audio/StemPlayer.swift` — AVAudioEngine graph: `AVAudioPlayerNode` per stem → `AVAudioMixerNode` → `AVAudioUnitTimePitch` → output
- `apps/ios/Intonavio/Audio/StemDownloader.swift` — fetch presigned URLs from `GET /v1/songs/:songId/stems/:stemId/url`, download to `Caches/stems/{songId}/`
- `apps/ios/Intonavio/Audio/AudioMode.swift` — enum: `original` (YT unmuted, no stems), `allStems` (YT muted, all), `vocalsOnly` (YT muted, vocals), `instrumental` (YT muted, all except vocals)
- `apps/ios/Intonavio/Features/Practice/StemMixerView.swift` — mode selector UI
- `apps/ios/IntonavioTests/Audio/StemPlayerTests.swift`

**Audio graph:**

```
PlayerNode(vocals) ──┐
PlayerNode(instr.) ──┤→ MixerNode → TimePitch → mainMixer → output
```

**Rate control:** `AVAudioUnitTimePitch.rate` preserves pitch when changing speed.

**Verify:** Switch to "All Stems" — YouTube mutes, stems play. "Vocals Only" — only vocals. "Instrumental" — no vocals. Speed changes work pitch-correctly.

---

### 4.8: Video-Audio Sync

**Files to create:**

- `apps/ios/Intonavio/Audio/VideoAudioSync.swift` — poll `getCurrentTime()` every 1s, correct if drift > 150ms, stem audio is master clock
- `apps/ios/Intonavio/Utilities/DriftLogger.swift` — debug-build drift logging (`ytTime`, `stemTime`, `correction`)
- Extend `PracticeViewModel.swift` — coordinate play/pause/seek/speed across both players
- `apps/ios/IntonavioTests/Audio/VideoAudioSyncTests.swift`

**Coordinated operations:** all play/pause/seek/speed go through `PracticeViewModel` which dispatches to both `StemPlayer` and `VideoPlayerProtocol`.

**Mode transitions:** `original` → stem mode: mute YT, start stems at current time, start sync. Stem mode → `original`: stop stems, stop sync, unmute YT.

**Verify:** Play in stem mode — video and stems stay in sync. Change speed — both update. A-B loop in stem mode — both loop together.

---

### 4.9: Session History + Detail

**Files to create/modify:**

- `apps/ios/Intonavio/Features/Sessions/SessionsViewModel.swift` — `@Observable`: fetch + paginate sessions
- `apps/ios/Intonavio/Features/Sessions/SessionHistoryView.swift` — `List` with infinite scroll pagination
- `apps/ios/Intonavio/Features/Sessions/SessionRowView.swift` — date, song title, duration, color-coded score
- `apps/ios/Intonavio/Features/Sessions/SessionDetailView.swift` — score, loop points, speed, duration (pitch graph placeholder for Phase 5)
- Extend `PracticeViewModel.swift` — save session on practice end (`POST /v1/sessions`)
- `apps/ios/IntonavioTests/Sessions/SessionsViewModelTests.swift`

**Session saving:** when leaving practice screen after >10s of playback, auto-save session. `pitchLog` is empty array in Phase 4 (populated in Phase 5).

**Verify:** Sessions tab shows past sessions. Tap → detail. Pagination works. After practice, session appears in list.

---

### 4.10: Settings + Exercise Browser + Polish

**Files to create/modify:**

- `apps/ios/Intonavio/Features/Settings/SettingsViewModel.swift` — account management
- `apps/ios/Intonavio/Features/Settings/SettingsView.swift` — account section, audio input, theme toggle
- `apps/ios/Intonavio/Features/Settings/ProfileView.swift` — read-only profile display (displayName, email, auth provider)
- `apps/ios/Intonavio/Features/Library/ExerciseBrowserView.swift` — placeholder with bundled exercise categories (Scales, Arpeggios, Intervals, Vibrato, Breathing)
- `apps/ios/Intonavio/Features/Library/ExerciseSectionView.swift` — horizontal scroll section on HomeView
- `apps/ios/Intonavio/App/AppTheme.swift` — theme management via `@AppStorage`

**Settings sections (limited by backend API):**

- **Account:** display name + email (read-only — no update endpoints exist), sign out button (clears Keychain), delete account with confirmation alert (`DELETE /v1/auth/account`)
- **Audio Input:** device selection via `AVAudioSession.availableInputs`
- **Theme:** System / Light / Dark toggle
- **About:** version, links

**Note:** Password change, email change, and profile editing require backend endpoints that don't exist yet. Settings UI should not show these options until the backend supports them.

**Verify:** Settings shows account info (read-only). Sign out works. Delete account with confirmation. Theme toggle. Exercise categories visible on Home.

---

### 4.11: Testing + Previews + Quality Gates

Audit all files against quality standards.

**Tests to finalize:** APIClientTests, CodableModelTests, AuthViewModelTests, LibraryViewModelTests, YouTubeURLValidatorTests, StemPlayerTests, VideoAudioSyncTests, SessionsViewModelTests

**Quality gates:**

| Check                 | Target              |
| --------------------- | ------------------- |
| SwiftLint             | 0 warnings          |
| File length           | <= 300 lines        |
| Function length       | <= 40 lines         |
| View body             | <= 150 lines        |
| Cyclomatic complexity | <= 10               |
| Nesting depth         | <= 3                |
| `#Preview` coverage   | Every view file     |
| No `print()`          | All via `AppLogger` |

**End-to-end verify:** Sign in → add song → wait READY → play with stems → set A-B loop → change speed → switch audio modes → leave practice → session saved → view in Sessions tab → settings → sign out.

---

## Sub-Phase Dependency Order

```
4.1 → 4.2 → 4.3 → 4.4 → 4.5 → 4.6 → 4.7 → 4.8 → 4.9 → 4.10 → 4.11
```

Each sub-phase produces a buildable app. Approximate file count: ~45 app files + ~8 test files.
