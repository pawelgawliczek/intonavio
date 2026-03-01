# Intonavio — Code Quality Standards

## Code Quality Thresholds

These are enforced in CI. PRs that violate them are blocked.

### Test Coverage

| Scope                       | Minimum             | Measured By                                              |
| --------------------------- | ------------------- | -------------------------------------------------------- |
| **Overall (API)**           | 80% line coverage   | Jest `--coverage`                                        |
| **Overall (Web)**           | 70% line coverage   | Jest/Vitest `--coverage`                                 |
| **Overall (Python worker)** | 80% line coverage   | `pytest --cov`                                           |
| **Algorithmic modules**     | 95% branch coverage | Pitch detection, scoring, exercise generator, cents math |
| **New code in PR**          | 80% line coverage   | CI diff coverage check                                   |

Algorithmic modules (YIN detector, scoring calculator, exercise pitch generator, cents deviation) are the most critical — a silent regression here affects every user. 95% branch coverage ensures all code paths including edge cases (silence, NaN, zero division) are tested.

### File Size Limits

| Metric                            | Limit | Rationale                                           |
| --------------------------------- | ----- | --------------------------------------------------- |
| **Max lines per file**            | 300   | Forces decomposition into focused modules           |
| **Max lines per function/method** | 40    | Functions that do one thing stay short              |
| **Max lines per Swift View**      | 150   | Extract subviews and modifiers beyond this          |
| **Max lines per React component** | 150   | Extract sub-components or custom hooks              |
| **Max lines per test file**       | 500   | Test files can be longer — readability over brevity |

### Code Complexity

| Metric                                 | Limit                                | Tool                                                        |
| -------------------------------------- | ------------------------------------ | ----------------------------------------------------------- |
| **Cyclomatic complexity per function** | ≤ 10                                 | ESLint `complexity` rule, SwiftLint `cyclomatic_complexity` |
| **Cognitive complexity per function**  | ≤ 15                                 | SonarQube / `eslint-plugin-sonarjs`                         |
| **Max nesting depth**                  | 3 levels                             | ESLint `max-depth`, SwiftLint `nesting`                     |
| **Max function parameters**            | 4                                    | Beyond 4, use an options/config object or struct            |
| **Max dependencies per module**        | 8 imports from other project modules | If a module imports from 8+ siblings, it's doing too much   |

### Linter Configs

- **TypeScript**: ESLint with `@typescript-eslint/strict`, `eslint-plugin-sonarjs`, Prettier
- **Swift**: SwiftLint with `strict` configuration
- **Python**: Ruff (linting + formatting), mypy strict mode

All linters run in CI as a pre-merge gate. No warnings allowed — treat warnings as errors.

## Code Quality Rules

### General

- No `any` types in TypeScript. Use `unknown` and narrow with type guards.
- No disabled linter rules (`eslint-disable`, `nolint`, `noqa`) without a comment explaining why.
- No `console.log` in committed code. Use the project logger (Pino for NestJS, `logging` for Python).
- No hardcoded secrets, URLs, or environment-specific values. Everything through environment variables validated at startup.
- No dead code. Don't comment out code "for later" — delete it, git has history.
- No barrel files (`index.ts` re-exports) except in `packages/shared`. Import from the specific module.
- Prefer `const` over `let`. Never use `var`.
- Prefer early returns over nested `if/else`.
- Functions do one thing. If a function name contains "and", split it.
- Max function length: ~40 lines. If longer, extract helpers.
- Name booleans as questions: `isReady`, `hasStems`, `canRetry`.
- Name functions as actions: `fetchSong`, `createSession`, `detectPitch`.

### TypeScript (API + Web)

- Strict mode enabled (`"strict": true` in tsconfig). No exceptions.
- All API request/response shapes defined as DTOs with `class-validator` decorators.
- All async functions must have error handling — no unhandled promise rejections.
- Use `readonly` for properties that shouldn't change after construction.
- Prefer `interface` for object shapes, `type` for unions and intersections.
- Use `satisfies` operator for type-safe object literals where inference is desired.
- Enums defined in `packages/shared` and imported by both API and Web.
- No relative imports that go up more than one level (`../../` max). Use path aliases.

### NestJS (API)

- One module per domain: `AuthModule`, `SongModule`, `StemModule`, `SessionModule`, `JobModule`.
- Controllers handle HTTP concerns only (status codes, headers, response shape). Business logic in services.
- Use `@UseGuards(JwtAuthGuard)` globally. Mark public routes with `@Public()`.
- Inject `ConfigService` for all environment variables. Never use `process.env` directly in services.
- Use `prisma.$transaction()` for multi-step writes (e.g., update song status + create stem records).
- Use explicit `select`/`include` in Prisma queries — never return full models with all relations.
- Structured logging with context: `this.logger.error('Stem download failed', { songId, jobId, error })`.
- All endpoints return consistent error shape: `{ statusCode, error, message }`.
- Validate all webhook payloads (StemSplit) against expected schema before processing.
- Environment variables validated at startup via Zod schema in `common/config/env.validation.ts`, wired into `ConfigModule.forRoot({ validate })`. Missing or invalid vars fail fast on boot.
- Every request gets a `traceId` via `TraceIdInterceptor` — reads from `X-Trace-ID` header or generates `trc_{hex}`. Attached to request context and response header for cross-service correlation.

### Prisma (Database)

- Migrations generated with `prisma migrate dev`, applied in production with `prisma migrate deploy`.
- Never use `db push` in production.
- Every new query pattern must have a corresponding index. Check `EXPLAIN ANALYZE` for queries over 10ms.
- Foreign keys always have `onDelete` behavior defined (usually `Cascade`).
- CUIDs for primary keys (not UUIDs or auto-increment).
- Slow query detection via `PrismaService.$extends({ query })` — warns on queries >100ms. Note: Prisma 6 removed the `$use` middleware API; use `$extends` instead.

### BullMQ (Jobs)

- All jobs must be idempotent — running the same job twice produces the same result.
- Typed job data interfaces: `StemSplitJobData`, `PitchAnalysisJobData`.
- Max 3 retries with exponential backoff. After that, mark as FAILED with descriptive error.
- Separate queues per job type with independent concurrency settings.
- Log job lifecycle: started, completed, failed with job ID and duration.

### SwiftUI (iOS/macOS)

- MVVM architecture. Views are declarative, ViewModels hold state and logic.
- Use `@Observable` macro (iOS 17+), not `ObservableObject`.
- `async/await` and `Task` for all async work. Cancel tasks when views disappear.
- Audio thread (`installTap` callback): no memory allocation, no locks, no UI updates. Dispatch results to main thread.
- Protocol-oriented API client (`APIClientProtocol`) for testability and SwiftUI previews.
- Configure `AVAudioSession` once at app startup. Handle interruptions (phone calls, alarms).
- Use `Codable` structs mirroring API response shapes. No manual JSON parsing.
- SwiftUI previews for every view with mock data.

#### Split Spectrum Design Language

The app uses a dark-mode-only "Voice Cockpit" aesthetic. All colors are defined in `App/DesignSystem.swift`.

**Color palette** (use these instead of system colors):

| Token                          | Hex             | Usage                                                |
| ------------------------------ | --------------- | ---------------------------------------------------- |
| `Color.intonavioBackground`    | `#0E0F12`       | Deep Charcoal — primary backgrounds                  |
| `Color.intonavioSurface`       | `#1C1E24`       | Lighter Charcoal — cards, surfaces, secondary panels |
| `Color.intonavioMagenta`       | `#D946EF`       | Gradient start — branding                            |
| `Color.intonavioAmber`         | `#F59E0B`       | Gradient end — branding                              |
| `Color.intonavioIce`           | `#E6F6FF`       | Ice — playheads, selected states, icons              |
| `Color.intonavioTextPrimary`   | `#FFFFFF`       | Primary text                                         |
| `Color.intonavioTextSecondary` | `#A1A1AA`       | Secondary text / metadata                            |
| `LinearGradient.intonavio`     | Magenta → Amber | CTA buttons, branding elements                       |

**Rules:**

- **Dark mode only.** `preferredColorScheme(.dark)` is forced at the root. No theme picker.
- **Backgrounds:** Use `Color.intonavioBackground`, never `Color(.systemBackground)`.
- **Surfaces/cards:** Use `Color.intonavioSurface`, never `Color(.systemGroupedBackground)`.
- **CTA buttons:** Use `PrimaryButtonStyle()` (gradient capsule) for primary actions (Sign In, Add Song, Try Again).
- **Secondary buttons:** Use `SecondaryButtonStyle()` (Ice border capsule).
- **Selected states:** Use `Color.intonavioIce` for selected controls, playheads, active toggles.
- **Inactive controls:** Use `Color.intonavioTextSecondary` foreground on `Color.intonavioSurface` background.
- **Functional accuracy colors are preserved:** Green, yellow, orange, red for pitch accuracy, score indicators, loop markers, and status badges. Do not replace these with design system colors.
- **Text:** Use `.white` or `Color.intonavioTextPrimary` for primary text, `Color.intonavioTextSecondary` for labels/metadata. Avoid `.secondary`/`.tertiary` semantic colors.
- **Toast/overlay backgrounds:** Use `Color.intonavioSurface` instead of `.ultraThinMaterial`.

### Next.js (Web)

- Server Components by default. Only `"use client"` for components needing browser APIs.
- Route handlers as BFF to proxy API calls with server-side auth tokens.
- AudioWorklet processor in a standalone `.js` file (not bundled). Place in `/public` or use raw loader.
- Audio objects (`AudioContext`, `MediaStream`, nodes) in `useRef`, not `useState` — they are mutable and should not trigger re-renders.
- `useEffect` cleanup: always stop media streams, close audio contexts, disconnect nodes.
- No `any` in component props — define explicit prop interfaces.

### Python (Pitch Worker)

- Type hints on all function signatures. Run `mypy` in strict mode with pydantic plugin.
- Pydantic models for job payloads (camelCase aliases for BullMQ interop) and output validation.
- Environment config via `pydantic-settings` `BaseSettings` — fails fast on missing required vars at startup.
- Pin exact dependency versions in `requirements.txt`.
- BullMQ consumer via `bullmq` Python package with 5-minute lock duration (pYIN extraction is CPU-bound, ~110s per song).
- Each job is process-isolated: download stem → extract pitch → upload JSON → update DB. No shared mutable state.
- CPU-bound pYIN runs in `ThreadPoolExecutor` via `run_in_executor` to avoid blocking the async BullMQ event loop.
- Validate pYIN output before uploading: reject if >90% of frames are unvoiced (bad audio) or all NaN.
- Idempotent database writes: `INSERT ... ON CONFLICT ("songId") DO UPDATE` for PitchData upserts.
- Structured JSON logging to stdout with `traceId`, `songId`, `durationMs` context fields.
- Use `from __future__ import annotations` in modules importing BullMQ `Job` (not subscriptable at runtime).
- Type-only imports in `TYPE_CHECKING` blocks (e.g., `mypy_boto3_s3.S3Client`, `bullmq.Job`).

### Cloudflare R2 (Storage)

- Presigned URLs for client downloads (15 min TTL). Never proxy file content through the API.
- Consistent key naming: `stems/{songId}/{TYPE}.mp3` (uppercase StemType enum value), `pitch/{songId}/reference.json`, `pitch/{exerciseId}/reference.json`.
- Set correct `Content-Type` on every upload (`audio/mpeg`, `application/json`).
- Set `Cache-Control: public, max-age=31536000, immutable` on stems (content-addressed, never changes).
