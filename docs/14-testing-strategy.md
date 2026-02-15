# Intonavio — Testing Strategy

Goal: automate all verification except subjective audio/visual quality. Human QA is limited to stem audio quality spot-checks, piano roll visual feel, and new device/OS testing before major releases.

## Level 1: Unit Tests (every commit, <30s)

Cover the algorithmic core where bugs are hardest to spot manually.

### Pitch Detection (Swift + JS)

- Feed known sine waves (440Hz, 261.63Hz, 329.63Hz) → assert detected frequency within ±1 Hz
- Test confidence threshold: noise input → confidence < 0.8, clean tone → confidence > 0.8
- Edge cases: silence → no detection, very low pitch (100Hz) → still detected with 1024 buffer

### Scoring Math

- `(440, 440) → 0 cents`, `(440, 466.16) → 100 cents`, `(440, 220) → -1200 cents`
- Frame arrays with known deviations → assert score matches expected
- All unvoiced reference frames → score excludes them (no division by zero)
- Transpose: octave up → reference shifts to 880Hz, singing 880Hz → excellent (100 score)
- Transpose: octave down → reference shifts to 220Hz, singing 220Hz → excellent
- Transpose: mismatch (440Hz detected vs 880Hz adjusted ref) → poor accuracy
- Transpose: zero offset → identical to no-transpose behavior
- Transpose: pitch log records adjusted reference Hz, not original

### Difficulty Levels

- Advanced boundary tests: ±25¢ excellent, ±40¢ good, ±60¢ fair, >60¢ poor
- Intermediate boundary tests: ±25¢ excellent, ±50¢ good, ±75¢ fair, >75¢ poor
- Beginner boundary tests: ±150¢ excellent, ±300¢ good, ±450¢ fair, >450¢ poor
- Points vary by level: excellent always 100; good 75/60/50; fair 40/25/20
- `PitchAccuracy.classify(cents:difficulty:)` and `.points(difficulty:)` tested per level

### Exercise Pitch Generator

- `{midi: 60, duration: 1.0, tempo: 60}` → assert 86 frames, all at 261.63 Hz
- Vibrato: `{midi: 60, vibrato: {cents: 30, rateHz: 5.5}}` → frequency oscillates within ±30 cents
- Rest periods → unvoiced frames with `hz: null`
- Tempo scaling: double tempo → half the frame count

### DTO Validation

- Invalid YouTube URL → rejected
- Missing required fields → rejected
- Score clamped to 0–100
- Malformed webhook payload → rejected

### Prisma Model Constraints

- Unique `videoId` enforced (duplicate insert fails)
- Cascading deletes (delete user → songs, sessions, attempts gone)
- `@@unique([songId, type])` prevents duplicate stems

### Job Idempotency

- Run same stem-split job handler twice → only one set of stems exists
- Run same pitch-analysis job twice → pitch data not duplicated

## Level 2: Integration Tests (every PR, ~2 min)

Test real interactions between components with a test PostgreSQL database and mock externals.

### API Endpoints (supertest)

- Full endpoint suite: every route in `docs/03-api-design.md` tested for auth, happy path, error cases
- POST /songs → DB record created + BullMQ job enqueued
- Webhook handler: simulated StemSplit payload → stems created in DB, R2 upload called
- Auth flow: mock Apple identity token → JWT issued, refresh works, expired token rejected
- Presigned URL generation → valid URL with correct expiry

### Job State Machine

- QUEUED → SPLITTING → ANALYZING → READY with assertions at each step
- Invalid transitions rejected (e.g., QUEUED → READY)
- FAILED state sets `errorMessage`

### Exercise Lifecycle

- Create exercise → generate pitch data → create attempt → verify scoring stored

### External Service Mocks

- StemSplit API: mock server returning fixture responses (success + failure + timeout)
- R2: mock `@aws-sdk/client-s3` — assert correct keys and content types
- Apple Sign In: mock JWKS endpoint returning test keys

## Level 3: Contract Tests (weekly or on dependency updates)

Catch breaking changes in external services. Cost: ~$0.40 per run (one StemSplit job).

- **StemSplit API**: hit real API with one cheap test song, assert response shape, webhook arrives, download URLs work
- **R2**: upload small test file to real R2, read back, verify, delete
- **Apple JWKS**: fetch real endpoint, assert key format unchanged

## Level 4: E2E Tests (before release)

Playwright for web, XCUITest for iOS. Only critical paths — keep count low.

| #   | Path                                                                               | Asserts                           |
| --- | ---------------------------------------------------------------------------------- | --------------------------------- |
| 1   | Sign in → submit YouTube URL → wait for READY → see stems                          | Song in library with status READY |
| 2   | Open song → play stems → set A-B loop → loop repeats                               | Playback loops between markers    |
| 3   | Open song → start practice → sing → see pitch on piano roll → stop → session saved | Session in history with score > 0 |
| 4   | Open exercise → practice → score displayed                                         | Exercise attempt recorded         |

**iOS E2E**: inject pre-recorded audio via AVAudioEngine test mode instead of real microphone — deterministic and CI-compatible.

## What Remains Manual

| Check                         | When                                    | Why                              |
| ----------------------------- | --------------------------------------- | -------------------------------- |
| Stem audio quality spot-check | StemSplit config change or user reports | Subjective quality               |
| Piano roll visual review      | After practice screen UI changes        | Animation/layout feel            |
| New device/OS testing         | Before major releases                   | Hardware-specific audio behavior |
