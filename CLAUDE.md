# Intonavio — Project Instructions

## Project Overview

Intonavio is a singing practice app (iOS → macOS → Web SaaS) that uses YouTube lyrics videos, stem separation (StemSplit API), and real-time pitch detection to help singers improve. See `docs/01-overview.md` for full product details.

## Tech Stack

- **API**: NestJS (TypeScript), Prisma, BullMQ, PostgreSQL 16, Redis 7
- **iOS/macOS**: SwiftUI, AVAudioEngine, WKWebView
- **Web**: Next.js 14, React 18, Tailwind CSS, AudioWorklet
- **Pitch Worker**: Python 3.11, librosa, pYIN
- **Storage**: Cloudflare R2 (stems + pitch data)
- **Auth**: Apple Sign In, Google OAuth, Email/Password, JWT
- **Infrastructure**: Docker Compose, Caddy reverse proxy
- **CI/CD**: GitHub Actions
- **Monorepo**: Turborepo, pnpm workspaces

## Critical Coding Rules

These rules apply to every code change. Full details in `docs/12-code-quality.md`.

### Absolute Prohibitions

- No `any` types in TypeScript — use `unknown` and narrow with type guards.
- No `console.log` in committed code — use the project logger (Pino for NestJS, `logging` for Python).
- No hardcoded secrets, URLs, or environment-specific values — use env vars validated at startup.
- No dead code — don't comment out code "for later", delete it.
- No barrel files (`index.ts` re-exports) except in `packages/shared`.
- No disabled linter rules without a comment explaining why.
- No `var` — use `const`, or `let` only when reassignment is needed.
- No `process.env` in NestJS services — inject `ConfigService`.
- No `db push` in production — use `prisma migrate deploy`.

### Naming & Style

- Booleans as questions: `isReady`, `hasStems`, `canRetry`.
- Functions as actions: `fetchSong`, `createSession`, `detectPitch`.
- Prefer early returns over nested `if/else`.
- Functions do one thing. If a function name contains "and", split it.

### Size Limits

- Max 300 lines per file, 40 lines per function, 150 lines per View/component.
- Max 4 function parameters — beyond that, use an options object.
- Max nesting depth: 3 levels.

### TypeScript Strict Mode

- `"strict": true` in tsconfig — no exceptions.
- All DTOs use `class-validator` decorators.
- Prefer `interface` for object shapes, `type` for unions/intersections.
- No relative imports deeper than `../../` — use path aliases.

### Architecture (quick reference)

- Dependencies point inward: Clients → API → Services → Infrastructure.
- Every external service behind an adapter interface (see `docs/02-architecture.md`).
- Controllers: HTTP concerns only. Business logic in services.
- All jobs must be idempotent.
- Clients are renderers of server state — no duplicated business logic.

### Git

- Imperative mood commits: `Add stem download endpoint`.
- One logical change per commit. All changes via PRs to `main`.

## Before Implementing

Before writing any code, read the docs relevant to the work:

- **Any backend change** (API, services, controllers) → read `docs/12-code-quality.md` (NestJS, Prisma, BullMQ sections), `docs/02-architecture.md` (Architecture Rules)
- **Any Python worker change** → read `docs/12-code-quality.md` (Python section), `docs/13-observability.md` (Python Worker debugging)
- **Any iOS/macOS change** → read `docs/12-code-quality.md` (SwiftUI section), `docs/13-observability.md` (iOS Client debugging), `docs/16-ui-views-flow.md` (views & navigation)
- **Any web change** → read `docs/12-code-quality.md` (Next.js section), `docs/13-observability.md` (Web Client debugging), `docs/16-ui-views-flow.md` (views & navigation)
- **Any new feature or endpoint** → read `docs/14-testing-strategy.md`, `docs/03-api-design.md`
- **Any infra or CI change** → read `docs/15-development-workflow.md`, `docs/08-infrastructure.md`
- **Any data model change** → read `docs/04-data-models.md`, `docs/12-code-quality.md` (Prisma section)
- **Any audio pipeline change** → read `docs/05-audio-pipeline.md`, `docs/06-realtime-pitch.md`

Always read `docs/12-code-quality.md` — it applies to every change.

## Documentation Reference

| Topic                        | Document                           |
| ---------------------------- | ---------------------------------- |
| Product overview             | `docs/01-overview.md`              |
| System architecture & rules  | `docs/02-architecture.md`          |
| API contracts                | `docs/03-api-design.md`            |
| Data models (Prisma)         | `docs/04-data-models.md`           |
| Audio processing pipeline    | `docs/05-audio-pipeline.md`        |
| Real-time pitch detection    | `docs/06-realtime-pitch.md`        |
| YouTube looping              | `docs/07-youtube-looping.md`       |
| Infrastructure & deployment  | `docs/08-infrastructure.md`        |
| Project structure            | `docs/09-project-structure.md`     |
| Implementation phases        | `docs/10-implementation-phases.md` |
| Spikes                       | `docs/11-spikes.md`                |
| Code quality standards       | `docs/12-code-quality.md`          |
| Observability & debugging    | `docs/13-observability.md`         |
| Testing strategy             | `docs/14-testing-strategy.md`      |
| Development workflow & CI/CD | `docs/15-development-workflow.md`  |
| UI views & navigation flow   | `docs/16-ui-views-flow.md`         |

Do not deviate from documented architecture without updating the relevant doc first.

## iOS Build

- When building for iOS Simulator, use `iPhone 17 Pro` as the destination (iPhone 16 is not available).
- Example: `xcodebuild -project apps/ios/Intonavio.xcodeproj -scheme Intonavio -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`

## Deployment

- Deploy flow: push to `main` → CI builds Docker images → deploys via SSH → runs migrations → health check
- See `docs/08-infrastructure.md` for full infrastructure details
- See `.github/workflows/deploy.yml` for the deploy pipeline
