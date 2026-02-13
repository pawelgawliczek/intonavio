# Intonavio — Implementation Phases

## Gantt Chart

```mermaid
gantt
    title Intonavio Implementation Phases
    dateFormat YYYY-MM-DD
    axisFormat %b %d

    section Spikes
    Spike A - iOS Pitch Detection       :spike-a, 2025-06-01, 5d
    Spike B - YouTube Looping WKWebView :spike-b, 2025-06-01, 5d
    Spike C - StemSplit API Integration  :spike-c, 2025-06-01, 5d

    section Backend
    Database Schema + Prisma            :db, after spike-c, 3d
    Auth Module (Apple + Google + Email) :auth, after db, 4d
    Song Module + StemSplit Integration  :songs, after auth, 7d
    Webhook Handler + Stem Storage      :webhook, after songs, 4d
    Session Module                      :sessions, after webhook, 3d
    API Testing + Polish                :api-test, after sessions, 3d

    section Pitch Worker
    Python Worker Scaffolding           :worker-scaffold, after db, 3d
    pYIN Analysis Pipeline              :pyin, after worker-scaffold, 5d
    R2 Upload + DB Integration          :worker-int, after pyin, 3d

    section Infrastructure
    CI Pipeline (lint + test + build)   :ci, after db, 3d
    Docker Compose + Caddy Setup         :docker, after ci, 3d
    Observability + Health Checks       :obs, after docker, 2d

    section iOS Core
    Project Setup + Navigation          :ios-setup, after api-test, 3d
    Auth Flow (Apple Sign In)           :ios-auth, after ios-setup, 3d
    Song Library + YouTube Player       :ios-library, after ios-auth, 5d
    A-B Looping Controls                :ios-loop, after ios-library, 5d
    Stem Playback + Audio Mode          :ios-stems, after ios-loop, 5d

    section iOS Pitch
    YIN Pitch Detector                  :ios-yin, after ios-stems, 5d
    Piano Roll Visualization            :ios-piano, after ios-yin, 5d
    Scoring + Session Recording         :ios-score, after ios-piano, 4d
    iOS Testing + Polish                :ios-test, after ios-score, 5d

    section Web
    Next.js Project Setup               :web-setup, after api-test, 3d
    Auth + Song Library Pages           :web-pages, after web-setup, 5d
    YouTube Player + Loop Controls      :web-yt, after web-pages, 5d
    AudioWorklet Pitch Detection        :web-pitch, after web-yt, 7d
    Piano Roll + Scoring                :web-piano, after web-pitch, 5d

    section macOS
    macOS Target from iOS Codebase      :macos, after ios-test, 10d
```

## Phase Dependency Graph

```mermaid
graph LR
    Spikes[Spikes<br/>A + B + C] --> Backend[Backend<br/>API + DB]
    Spikes --> PitchWorker[Pitch Worker<br/>Python pYIN]
    Spikes --> Infra[Infrastructure<br/>CI + Docker + Observability]

    Backend --> iOSCore[iOS Core<br/>Auth + Library + Looping]
    Backend --> WebApp[Web App<br/>Next.js]
    PitchWorker --> iOSCore
    Infra --> iOSCore
    Infra --> WebApp

    iOSCore --> iOSPitch[iOS Pitch<br/>YIN + Piano Roll]
    WebApp --> WebPitch[Web Pitch<br/>AudioWorklet]

    iOSPitch --> macOS[macOS<br/>Shared codebase]
```

---

## Phase Details

### Phase 0: Spikes (Validation)

> See `docs/11-spikes.md` for detailed spike plans.

**Goal:** Validate the three riskiest technical assumptions before committing to full implementation.

| Spike | Question                                                         | Deliverable                                     |
| ----- | ---------------------------------------------------------------- | ----------------------------------------------- |
| A     | Can we detect pitch in real time on iOS with acceptable latency? | Working YIN prototype with latency measurements |
| B     | Can we embed YouTube in WKWebView with programmatic A-B looping? | Prototype with seek, loop, and speed control    |
| C     | Does StemSplit API meet our quality and latency needs?           | Integration test with cost and timing data      |

**Exit criteria:** All three spikes pass → proceed to Phase 1. Any spike fails → re-evaluate approach.

---

### Phase 1: Backend ✅ COMPLETE

**Goal:** Fully functional API server that handles auth, song processing, and session storage.

> **Status:** All 11 sub-phases implemented and verified. 92 unit tests + 23 e2e tests passing, lint clean, build clean. Deployed to Hostinger KVM, verified: health check (DB + Redis up), user registration (JWT tokens), song submission (202 QUEUED). Live at `https://api.intonavio.pawelgawliczek.cloud`. See `docs/implementation_plans/backend.md` for detailed sub-phase breakdown.

**Deliverables:**

- PostgreSQL schema deployed via Prisma migrations with CUIDs for primary keys, `onDelete` behavior on all foreign keys, and indexes for all query patterns (see `docs/12-code-quality.md` — Prisma rules)
- Auth module supporting Apple Sign In, Google OAuth, and Email/Password with JWT issuance (see `docs/02-architecture.md` — External Service Isolation for `AuthProviderService` adapter)
- Song submission → StemSplit job → webhook → R2 storage pipeline with `traceId` correlation across all steps (see `docs/13-observability.md`)
- All external services wrapped behind adapter interfaces: `StemSplitService`, `StorageService`, `AuthProviderService` (see `docs/02-architecture.md` — External Service Isolation)
- Session CRUD endpoints with pagination (`?page=1&limit=20`) on all list endpoints (see `docs/02-architecture.md` — API Contract Rules)
- BullMQ jobs are idempotent with typed data interfaces, 3 retries with exponential backoff, and structured lifecycle logging (see `docs/12-code-quality.md` — BullMQ rules)
- Controllers handle HTTP concerns only; business logic in services. One module per domain (see `docs/02-architecture.md` — Module Boundary Rules)
- Consistent error shape `{ statusCode, error, message }` on all endpoints. 4xx for client errors, 5xx for server errors (see `docs/02-architecture.md` — Error Propagation)
- Integration tests for all endpoints using supertest with mock externals (see `docs/14-testing-strategy.md` — Level 2)
- 80% line coverage minimum, 95% branch coverage on algorithmic modules (see `docs/12-code-quality.md` — Test Coverage)
- Structured JSON logging with mandatory fields: `traceId`, `module`, `durationMs` (see `docs/13-observability.md` — Structured Logging)
- Health endpoints: `GET /health` and `GET /health/detailed` (see `docs/13-observability.md` — Health Checks)
- Deployed to Hostinger KVM via Docker Compose (see `docs/08-infrastructure.md`)

**Quality gates:**

- All linters pass (ESLint strict + Prettier), no warnings
- Max 300 lines per file, 40 lines per function, cyclomatic complexity ≤ 10
- No `any` types, no `console.log`, no `process.env` in services
- All webhook payloads validated against expected schema

---

### Phase 2: Pitch Worker ✅ COMPLETE

**Goal:** Python worker that extracts reference pitch from vocal stems.

> **Status:** All 8 sub-phases implemented and verified. 43 unit tests passing, ruff lint/format clean, mypy strict clean, 83% overall coverage (80% threshold), 100% coverage on `analyzer.py` (95% threshold). Deployed to Hostinger KVM, verified on 2 songs — both transitioned from ANALYZING → READY with valid pitch data. See `docs/implementation_plans/pitch-worker.md` for detailed sub-phase breakdown.

**Deliverables:**

- BullMQ consumer (`consumer.py`) that listens on the `pitch-analysis` queue with 5-minute lock duration for CPU-bound pYIN extraction
- pYIN extraction pipeline (`analyzer.py`) with configurable parameters (fmin=65, fmax=2093, hop_length=512), all parameters logged for reproducibility (see `docs/13-observability.md` — Python Worker debugging)
- Validation: reject output if >90% of frames are unvoiced or all NaN (see `docs/12-code-quality.md` — Python rules)
- JSON pitch data upload to R2 with key `pitch/{songId}/reference.json` and `Content-Type: application/json` (see `docs/12-code-quality.md` — R2 rules)
- Database status updates (song ANALYZING → READY) via psycopg2 transactions with idempotent `ON CONFLICT DO UPDATE` upserts
- Pydantic models (`models.py`) for job payloads (camelCase aliases for BullMQ interop) and output validation
- Environment configuration (`config.py`) via pydantic-settings with fail-fast startup validation
- Structured JSON logging (`logger.py`) with mandatory fields: level, timestamp, service, module, message, traceId, songId, durationMs (see `docs/13-observability.md`)
- Stdout heartbeat every 60s for health monitoring
- Type hints on all function signatures, mypy strict mode
- Process-isolated: download stem → extract pitch → upload JSON → update DB. No shared mutable state
- 83% overall line coverage, 100% branch coverage on `analyzer.py` (pYIN extraction and MIDI math)
- Deployed to Hostinger KVM as Docker container with CPU/memory limits (2 CPU, 2G RAM)

**Quality gates:**

- Ruff linting + formatting passes, mypy strict passes
- Exact dependency versions pinned in `requirements.txt`
- Job idempotency verified: `ON CONFLICT ("songId") DO UPDATE` ensures re-runs produce same result
- Verified on production: 2 songs processed (20,501 and 26,679 frames, 62.7% and 69.1% voiced)

---

### Phase 3: Infrastructure & CI/CD

**Goal:** Automated build/test/deploy pipeline and production infrastructure.

**Deliverables:**

- CI workflow (`ci.yml`): pnpm install → lint → test → coverage check → build → Docker image build on every PR (see `docs/15-development-workflow.md`)
- Deploy workflow (`deploy.yml`): build images → push to ghcr.io → SSH to Hostinger → pull + up → migrate → health check on merge to `main`
- Backup workflow (`backup.yml`): daily pg_dump → R2, retain 30 days
- Docker Compose production setup with all containers: api, web, worker, postgres, redis on `stack_appnet` network (see `docs/08-infrastructure.md`)
- Caddy reverse proxy with automatic TLS (shared instance at `/opt/caddy` on Hostinger)
- Sentry integration for API, worker, iOS, and web with `traceId` tags (see `docs/13-observability.md` — Error Reporting)
- Coverage thresholds enforced in CI: 80% overall, 95% algorithmic, 80% new code in PR (see `docs/12-code-quality.md`)
- All linter configs: ESLint strict + sonarjs, SwiftLint strict, Ruff + mypy strict — warnings treated as errors

**Quality gates:**

- `main` branch protected: requires PR with passing CI
- Squash merge only for clean history

---

### Phase 4: iOS Core

**Goal:** iOS app with authentication, song library, YouTube playback, and A-B looping.

**Deliverables:**

- SwiftUI app with 3-tab navigation (Library, Sessions, Settings), MVVM architecture (see `docs/12-code-quality.md` — SwiftUI rules, `docs/16-ui-views-flow.md` for all 11 views)
- `@Observable` macro (iOS 17+) for all ViewModels, not `ObservableObject`
- Auth views: Sign In (Apple/Google/Email) and Sign Up
- Home view with song library grid + exercises section (horizontal scrollable categories)
- Add Song sheet with URL input, validation, and processing progress
- Exercise Browser for community exercises with category/difficulty filters
- Apple Sign In integration with backend JWT via `APIClientProtocol` (protocol-oriented for testability)
- YouTube player in WKWebView with JS bridge via `VideoPlayerProtocol` adapter (see `docs/02-architecture.md` — External Service Isolation)
- A-B loop controls with visual markers on timeline (see `docs/07-youtube-looping.md`)
- Stem playback via AVAudioEngine with audio mode toggle
- Video-audio sync mechanism with drift logging (see `docs/13-observability.md` — iOS Client debugging)
- `AVAudioSession` configured once at app startup with interruption handling
- `Codable` structs mirroring API response shapes, no manual JSON parsing
- `async/await` and `Task` for all async work, tasks cancelled when views disappear
- SwiftUI previews for every view with mock data
- Network request logging in debug builds

**Quality gates:**

- SwiftLint strict passes, no warnings
- Max 150 lines per View, 40 lines per method, cyclomatic complexity ≤ 10
- Audio thread (`installTap` callback): no allocation, no locks, no UI updates

---

### Phase 5: iOS Pitch

**Goal:** Real-time pitch detection, piano roll visualization, and scoring.

**Deliverables:**

- YIN pitch detector running on microphone input with 95% branch coverage on detection + scoring + cents math (see `docs/14-testing-strategy.md` — Level 1)
- Unit tests: known sine waves (440Hz, 261.63Hz, 329.63Hz) → detected within ±1 Hz; silence → no detection; noise → low confidence
- Song Practice view with toggleable layout: lyrics-focused (65/35) and pitch-focused (25/75) (see `docs/16-ui-views-flow.md`)
- Exercise Practice view with pitch graph, target notes, and tempo/metronome guide
- Piano roll view with 3 visualization modes: Zones+Line, Two Lines, Zones+Glow (see `docs/16-ui-views-flow.md`)
- Color-coded accuracy feedback (green ±10¢, yellow-green ±25¢, yellow ±50¢, red >50¢)
- Per-session scoring: cents deviation calculation with division-by-zero protection for unvoiced frames
- Session recording and review with `pitchLog` JSON for debug reproducibility (see `docs/13-observability.md`)
- Pitch detection debug mode (dev settings toggle): records raw mic input + detected frequencies for "scoring feels wrong" reports
- TestFlight beta build

**Quality gates:**

- Scoring math: `(440, 440) → 0 cents`, `(440, 466.16) → 100 cents`, `(440, 220) → -1200 cents` all pass
- Exercise pitch generator: vibrato oscillation within ±cents, rest periods produce `hz: null`

---

### Phase 6: Web App

**Goal:** Browser-based version with feature parity to iOS.

**Deliverables:**

- Next.js app with Server Components by default, `"use client"` only for browser API components (see `docs/12-code-quality.md` — Next.js rules)
- Authentication (web-based Apple Sign In, Google OAuth, or email) via route handler BFF proxying API calls with server-side auth tokens
- Song library and YouTube player pages with A-B loop controls
- AudioWorklet-based pitch detection — processor in standalone `.js` file in `/public`, not bundled
- Audio objects (`AudioContext`, `MediaStream`, nodes) in `useRef`, not `useState`
- `useEffect` cleanup: stop media streams, close audio contexts, disconnect nodes on unmount
- Piano roll visualization (Canvas) with frame drop detection (warn if <30fps) (see `docs/13-observability.md` — Web Client debugging)
- Scoring and session history
- AudioWorklet errors explicitly forwarded to main thread for error reporting (Sentry browser SDK)
- `performance.mark()` / `performance.measure()` around pitch detection cycle
- No `any` in component props — explicit prop interfaces
- 70% line coverage minimum, 95% branch coverage on pitch detection and scoring
- Deployed to Hostinger KVM as Docker container behind Caddy (see `docs/08-infrastructure.md`)

**Quality gates:**

- ESLint strict + sonarjs + Prettier passes, no warnings
- Max 150 lines per component, 300 lines per file
- E2E tests (Playwright): sign in → submit URL → READY, play + loop, practice + score (see `docs/14-testing-strategy.md` — Level 4)

---

### Phase 7: macOS

**Goal:** macOS app derived from the iOS codebase.

**Deliverables:**

- macOS target in the Xcode project
- UI adaptations for larger screen (sidebar navigation, resizable piano roll)
- Keyboard shortcuts for looping and playback control (see `docs/07-youtube-looping.md` — shortcuts)
- Same code quality standards as iOS: SwiftLint strict, MVVM, `@Observable`, previews
- Mac App Store submission
