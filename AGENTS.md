# Intonavio - Codex Project Instructions

## Scope

These instructions apply to the entire repository.

## Project Summary

Intonavio is a singing practice app for iOS first, then macOS and Web. It turns
YouTube lyrics videos into practice sessions with stem separation, A-B looping,
real-time pitch detection, piano roll feedback, scoring, offline practice,
synced lyrics, and instrument-recorded custom exercises.

Primary stack:

- API: NestJS, TypeScript, Prisma, BullMQ, PostgreSQL 16, Redis 7
- iOS/macOS: SwiftUI, AVAudioEngine, WKWebView, XcodeGen
- Web: Next.js 14, React 18, Tailwind CSS, AudioWorklet
- Workers: Python 3.11, librosa/pYIN pitch analyzer, BS-Roformer stem splitter
- Storage: Cloudflare R2 for stems and pitch JSON
- Infrastructure: Docker Compose, Caddy, GitHub Actions, Sentry
- Monorepo: pnpm workspaces and Turborepo

## Documentation To Read

Always read `docs/12-code-quality.md` before code changes. Also read the
relevant domain docs before implementing:

| Work area                            | Required docs                                                                              |
| ------------------------------------ | ------------------------------------------------------------------------------------------ |
| Backend/API/services/controllers     | `docs/12-code-quality.md`, `docs/02-architecture.md`, `docs/03-api-design.md`              |
| Data model or Prisma changes         | `docs/04-data-models.md`, `docs/12-code-quality.md`                                        |
| Python pitch worker                  | `docs/12-code-quality.md`, `docs/13-observability.md`, `docs/05-audio-pipeline.md`         |
| Stem separation or audio pipeline    | `docs/05-audio-pipeline.md`, `docs/08-infrastructure.md`                                   |
| iOS/macOS app                        | `docs/12-code-quality.md`, `docs/13-observability.md`, `docs/16-ui-views-flow.md`          |
| Real-time pitch, scoring, piano roll | `docs/06-realtime-pitch.md`, `docs/yin-comparison-results.md`                              |
| YouTube playback/looping             | `docs/07-youtube-looping.md`                                                               |
| Web app                              | `docs/12-code-quality.md`, `docs/13-observability.md`, `docs/16-ui-views-flow.md`          |
| Instrument recording                 | `docs/17-instrument-recording.md`, `docs/05-audio-pipeline.md`, `docs/16-ui-views-flow.md` |
| Offline practice, lyrics, onboarding | `docs/10-implementation-phases.md`, `docs/16-ui-views-flow.md`, `docs/20-onboarding.md`    |
| Testing strategy                     | `docs/14-testing-strategy.md`                                                              |
| Infra, deployment, CI/CD             | `docs/08-infrastructure.md`, `docs/15-development-workflow.md`                             |

`CLAUDE.md` references `docs/19-monetization.md`, which is not present in this
checkout and may be gitignored/local-only. If work touches subscriptions,
credits, paywalls, or monetization, look for that file locally first and ask
before making product assumptions.

Do not deviate from documented architecture without updating the relevant docs.

## Repository Layout

- `apps/api`: NestJS backend, Prisma schema, e2e tests
- `apps/web`: Next.js web client
- `apps/ios`: SwiftUI iOS/macOS project managed by XcodeGen
- `packages/shared`: shared TypeScript enums/types
- `workers/pitch-analyzer`: Python pYIN pitch analysis worker
- `workers/stem-splitter`: Python BS-Roformer stem separation worker
- `docs`: product, architecture, API, data, audio, UI, testing, infra docs

## Current Documented State

`docs/10-implementation-phases.md` says these areas are complete: backend, pitch
worker, infrastructure/CI, iOS core, iOS pitch, instrument recording, offline
practice, lyrics overlay, YouTube search with lyrics detection, and dual stem
sources. Web app and macOS remain documented platform phases. Verify against the
actual code before relying on phase notes.

## Hard Rules

- No TypeScript `any`; use `unknown` and narrow with type guards.
- No committed `console.log`; use Pino/Nest logger, `os.Logger`, or Python
  `logging` as appropriate.
- No hardcoded secrets, URLs, or environment-specific values; use validated env
  config.
- No dead/commented-out code kept "for later".
- No barrel files except in `packages/shared`.
- No disabled lint rules without a comment explaining why.
- No `var`; prefer `const`, use `let` only for reassignment.
- No `process.env` in NestJS services; inject `ConfigService`.
- Never use Prisma `db push` in production; use migrations and
  `prisma migrate deploy`.
- Keep files under 300 lines, functions under about 40 lines, Swift/React views
  under 150 lines, max nesting depth 3, max 4 parameters unless using an options
  object.
- Functions do one thing. If the function name needs "and", split it.
- Booleans read as questions: `isReady`, `hasStems`, `canRetry`.
- Functions read as actions: `fetchSong`, `createSession`, `detectPitch`.

## Architecture Rules

- Dependencies point inward: clients -> API -> services -> infrastructure.
- Clients never talk directly to DB/R2/Redis. Presigned URLs generated by the API
  are the exception for file downloads.
- Python workers are standalone: read from Redis/BullMQ, write to R2 and
  PostgreSQL, do not call the NestJS API.
- Every external service is behind an adapter/interface.
- PostgreSQL owns relational data; R2 owns audio and pitch JSON; Redis owns
  rebuildable queue/cache state only.
- Every state value has one source of truth. Do not make caches authoritative.
- API contracts are URL-versioned (`/v1/...`). Changes inside a version must be
  additive.
- Paginate all list endpoints from the start.
- NestJS controllers handle HTTP only; business logic lives in services.
- BullMQ jobs must be idempotent, typed, retried at most 3 times with exponential
  backoff, and logged through their lifecycle.
- Errors must propagate visibly: workers mark FAILED state, API returns proper
  4xx/5xx, clients show resource-specific errors.

## Area-Specific Guidance

### TypeScript, API, and Web

- Keep TypeScript strict.
- DTOs use `class-validator` decorators.
- Prefer interfaces for object shapes and type aliases for unions/intersections.
- Use path aliases instead of imports deeper than `../../`.
- Use explicit Prisma `select`/`include`; do not return full models casually.
- Use `prisma.$transaction()` for multi-step writes.
- Next.js uses Server Components by default; use `"use client"` only for browser
  APIs.
- Keep `AudioContext`, `MediaStream`, and audio nodes in refs, not React state.
- Stop media streams, close contexts, and disconnect nodes in cleanup.

### SwiftUI

- Use MVVM. Views are declarative; ViewModels hold state and logic.
- Use `@Observable` for iOS 17+, not `ObservableObject`.
- Use `async/await` and cancel tasks when views disappear.
- Audio tap callbacks must not allocate, lock, or update UI.
- API clients are protocol-oriented for tests and previews.
- Use Codable structs matching API responses; no manual JSON parsing.
- App design is dark-mode-only "Voice Cockpit"; use tokens in
  `App/DesignSystem.swift`.

### Python Workers

- Type hints on all signatures, mypy strict, Ruff lint/format.
- Config via `pydantic-settings`; fail fast on missing required env vars.
- Pydantic models validate BullMQ payloads and outputs.
- Pin exact dependencies in `requirements.txt`.
- CPU-bound pYIN runs in an executor so the BullMQ event loop is not blocked.
- Validate pitch output before upload; reject mostly unvoiced/all-NaN data.
- Structured JSON logs include `traceId`, resource IDs, and `durationMs`.

## Commands

Root workspace:

- `pnpm dev`: run Turbo dev tasks
- `pnpm build`: build all TypeScript packages/apps
- `pnpm lint`: lint all packages
- `pnpm test`: run all tests
- `pnpm format:check`: check formatting
- `pnpm db:generate`: generate Prisma client through Turbo

API:

- `pnpm --filter @intonavio/api build`
- `pnpm --filter @intonavio/api lint`
- `pnpm --filter @intonavio/api test`
- `pnpm --filter @intonavio/api test:e2e`
- `pnpm --filter @intonavio/api test:cov`
- `pnpm --filter @intonavio/api db:migrate`
- `pnpm --filter @intonavio/api db:migrate:deploy`

Web:

- `pnpm --filter @intonavio/web dev`
- `pnpm --filter @intonavio/web build`
- `pnpm --filter @intonavio/web lint`
- `pnpm --filter @intonavio/web test`
- `pnpm --filter @intonavio/web test:cov`

Shared package:

- `pnpm --filter @intonavio/shared build`
- `pnpm --filter @intonavio/shared lint`

Python workers, from the worker directory:

- `python -m pytest`
- `ruff check .`
- `ruff format --check .`
- `mypy src tests`

iOS/macOS:

- After adding/removing Swift files: `cd apps/ios && xcodegen generate`
- iOS simulator build destination: `iPhone 17 Pro`
- Example: `xcodebuild -project apps/ios/Intonavio.xcodeproj -scheme Intonavio -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`

Local infrastructure:

- `docker-compose -f docker-compose.dev.yml up -d`

## Verification Expectations

- Match verification scope to risk. At minimum, run the targeted lint/test/build
  command for touched code.
- Algorithmic pitch/scoring changes need focused unit coverage and should respect
  the documented 95% branch coverage target for those modules.
- API changes need DTO validation tests, service tests, and e2e coverage for
  route behavior when practical.
- Prisma changes need migrations, indexes for new query patterns, and explicit
  `onDelete` behavior.
- iOS audio/pitch changes need tests for math and state machines, plus a build
  when feasible.
- Web audio changes need tests for cleanup/error paths and careful browser API
  lifecycle handling.
- Keep observability intact: trace IDs, structured logs, resource IDs, and
  reproducible debug artifacts for pitch/scoring/sync issues.

## Git Workflow

- Default branch is `main`.
- Branch names: `feat/description`, `fix/description`, `spike/description`.
- Commits use imperative mood, e.g. `Add stem download endpoint`.
- Keep one logical change per commit.
- PRs should include what changed and how to test.
- All changes are expected to pass CI before merge.
