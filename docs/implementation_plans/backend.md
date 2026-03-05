# Intonavio Backend — Complete Implementation Plan

## Context

The Backend phase builds the full NestJS API server that handles auth, song processing, stem storage, and session management. The monorepo scaffold exists (Turborepo + pnpm), shared types are complete, Prisma schema has all 8 models, and empty module shells are in place.

A `UserSongLibrary` join table has been added so multiple users can share the same processed song (process once, serve many).

---

## Phase 1: Foundation — Database, Logging, Common Infrastructure ✅ COMPLETE

Everything depends on this phase. No other module can work without migrations, guards, decorators, filters, and logging.

**Status:** All sub-tasks implemented. `pnpm lint` and `pnpm build` pass cleanly.

### 1.1 Schema update — Add `UserSongLibrary` join table ✅

**Modified:** `apps/api/prisma/schema.prisma` — Added `UserSongLibrary` model with `userId`, `songId`, `addedAt`, `@@unique([userId, songId])`, indexes on both FKs. Added `userSongLibrary UserSongLibrary[]` relation on both `User` and `Song` models.

**Modified:** `packages/shared/src/types.ts` — Added `UserSongLibrary` interface.

### 1.2 Generate initial Prisma migration ✅

Migration `20260211063415_init` applied successfully. Creates all 9 tables (User, AuthProvider, Song, UserSongLibrary, Stem, PitchData, Session, Exercise, ExerciseAttempt), 4 enums, all indexes, unique constraints, and foreign keys with CASCADE deletes.

**File:** `apps/api/prisma/migrations/20260211063415_init/migration.sql`

### 1.3 Install missing dependencies ✅

Installed: `bcrypt`, `@aws-sdk/client-s3`, `@aws-sdk/s3-request-presigner`, `nestjs-pino`, `pino-http`, `jwks-rsa`, `google-auth-library`, `@nestjs/bullmq`, `@nestjs/terminus`, `ioredis`, `@types/bcrypt`, `pino-pretty` (dev).

### 1.4 Environment validation ✅

**Created:** `apps/api/src/common/config/env.validation.ts` — Zod schema validating all required env vars (DATABASE_URL, REDIS_URL, JWT_SECRET, JWT_EXPIRATION, JWT_REFRESH_EXPIRATION, Apple/Google/StemSplit/R2 credentials, SENTRY_DSN optional, NODE_ENV).

**Modified:** `apps/api/src/app.module.ts` — Added `validate` to `ConfigModule.forRoot()`.

**Modified:** `.env.example` — Added `JWT_REFRESH_EXPIRATION=7d`, `STEMSPLIT_WEBHOOK_SECRET`, changed `JWT_EXPIRATION` default to `15m`.

### 1.5 Pino logger setup ✅

**Created:** `apps/api/src/common/logger/logger.config.ts` — JSON output in production, `pino-pretty` in dev, includes `service` field in every log line.

**Modified:** `apps/api/src/main.ts` — Added `bufferLogs: true`, `app.useLogger(app.get(Logger))`.

**Modified:** `apps/api/src/app.module.ts` — Imported `LoggerModule.forRoot(createLoggerConfig())`.

### 1.6 Prisma slow query extension ✅

**Modified:** `apps/api/src/prisma/prisma.service.ts` — Uses Prisma `$extends` query extension (not `$use` which was removed in Prisma 6) to warn on queries >100ms with `{ model, action, durationMs }`.

**Implementation note:** Prisma 6 removed the `$use` middleware API. The equivalent is `$extends({ query: { $allModels: { $allOperations } } })`. The logger reference is captured in a closure since `this` inside `$extends` doesn't refer to the PrismaService instance.

### 1.7 Common decorators, guards, filters, interceptors ✅

**Created (7 files):**

| File                                              | Purpose                                                                                   |
| ------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| `src/common/decorators/public.decorator.ts`       | `@Public()` — sets `isPublic` metadata to skip auth                                       |
| `src/common/decorators/user.decorator.ts`         | `@User()` — param decorator extracting `RequestUser { userId, email }` from request       |
| `src/common/guards/jwt-auth.guard.ts`             | Global guard extending `AuthGuard('jwt')`, checks `@Public()` via Reflector               |
| `src/common/filters/http-exception.filter.ts`     | Consistent error shape `{ statusCode, error, message, traceId? }`, logs with context      |
| `src/common/interceptors/logging.interceptor.ts`  | Logs `{ method, path, statusCode, durationMs, userId, traceId }` on every request         |
| `src/common/interceptors/trace-id.interceptor.ts` | Reads `X-Trace-ID` header or generates `trc_{hex}`, attaches to request + response header |
| `src/common/pipes/parse-cuid.pipe.ts`             | Validates CUID format (`/^c[a-z0-9]{24}$/`) on `:id` params                               |

**Modified:** `apps/api/src/main.ts` — Registered global guard (`JwtAuthGuard`), filter (`HttpExceptionFilter`), interceptors (`TraceIdInterceptor`, `LoggingInterceptor`).

### 1.8 Pagination DTO (shared across modules) ✅

**Created:** `apps/api/src/common/dto/pagination.dto.ts`

- `PaginationQueryDto` with `page` (default 1) and `limit` (default 20, max 100) — class-validator decorated
- `PaginatedResponse<T>` interface with `{ data: T[], meta: { page, limit, total, totalPages } }`

---

## Phase 2: Storage Module (External Adapter) ✅ COMPLETE

Dependency of Stems, Webhooks, and Jobs. Must be built before them.

**Status:** All files implemented. Build, lint, and 9 tests pass.

**Created:** `src/storage/storage.interface.ts` — `StorageAdapter` interface with `upload(key, body, contentType, cacheControl?)`, `getPresignedUrl(key, expiresIn?)`, `delete(key)`, `headObject(key)` returning `HeadObjectResult | null`.

**Created:** `src/storage/storage.service.ts` — R2 implementation using `@aws-sdk/client-s3`. S3Client configured for R2 endpoint (`https://{accountId}.r2.cloudflarestorage.com`), region `auto`. Auto-applies `Cache-Control: public, max-age=31536000, immutable` on `stems/` keys. Default 15min presigned URL TTL. `headObject` returns `null` for NotFound/NoSuchKey errors.

**Modified:** `src/storage/storage.module.ts` — `@Global()` module, provides + exports `StorageService`.

**Created:** `src/storage/storage.service.spec.ts` — 9 tests with mocked S3Client and getSignedUrl. Covers upload (normal, auto-cache-control for stems, explicit cache-control), presigned URLs (default and custom TTL), delete, headObject (exists, not found, rethrow other errors).

---

## Phase 3: Auth Module ✅ COMPLETE

All other modules require authenticated users.

**Create (12 files):**

| File                                            | Contents                                                                                                                                                                                            |
| ----------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `src/auth/strategies/jwt.strategy.ts`           | PassportStrategy extracting JWT from Bearer header, validates with JWT_SECRET, returns `{ userId, email }`                                                                                          |
| `src/auth/dto/apple-sign-in.dto.ts`             | `{ identityToken, authorizationCode, fullName? }`                                                                                                                                                   |
| `src/auth/dto/google-sign-in.dto.ts`            | `{ code, redirectUri }`                                                                                                                                                                             |
| `src/auth/dto/register.dto.ts`                  | `{ email, password (min 8), displayName }`                                                                                                                                                          |
| `src/auth/dto/login.dto.ts`                     | `{ email, password }`                                                                                                                                                                               |
| `src/auth/dto/refresh.dto.ts`                   | `{ refreshToken }`                                                                                                                                                                                  |
| `src/auth/dto/auth-response.dto.ts`             | `{ accessToken, refreshToken, user: { id, email, displayName } }`                                                                                                                                   |
| `src/auth/providers/auth-provider.interface.ts` | `VerifiedIdentity { providerId, email, displayName }`                                                                                                                                               |
| `src/auth/providers/apple-auth.provider.ts`     | Uses `jwks-rsa` to verify Apple identity token via JWKS. Extracts sub, email.                                                                                                                       |
| `src/auth/providers/google-auth.provider.ts`    | Uses `google-auth-library` OAuth2Client. Exchanges code for tokens, verifies id_token.                                                                                                              |
| `src/auth/auth.service.ts`                      | Core auth logic (~120 lines): `signInWithApple`, `signInWithGoogle`, `register`, `login`, `refresh`, `deleteAccount`, private `findOrCreateUser`, private `issueTokens` (access 15min + refresh 7d) |
| `src/auth/auth.controller.ts`                   | 6 endpoints all `@Public()` except DELETE /auth/account                                                                                                                                             |

**Modify:** `src/auth/auth.module.ts` — Import JwtModule.registerAsync, PassportModule; wire all providers/controllers/exports

**Endpoints:**

- `POST /auth/apple` (public) — Exchange Apple token for JWT
- `POST /auth/google` (public) — Exchange Google auth code for JWT
- `POST /auth/register` (public) — Email+password registration, returns 201
- `POST /auth/login` (public) — Email+password login
- `POST /auth/refresh` (public) — Refresh access token
- `DELETE /auth/account` (auth required) — Delete account + all data, returns 204

**Tests:**

- Unit: AuthService with mocked Prisma/JWT/providers — register, login, refresh, findOrCreateUser
- Unit: AppleAuthProvider with mocked JWKS
- Unit: GoogleAuthProvider with mocked OAuth2Client
- Integration: supertest on all 6 endpoints with valid/invalid DTOs, 401 on protected route

---

## Phase 4: Jobs Module (BullMQ Infrastructure) ✅ COMPLETE

Must exist before Songs (which enqueues jobs) and Webhooks (which processes results).

**Create (5 files):**

| File                                          | Contents                                                                                                                                                                  |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `src/jobs/interfaces/job-data.interface.ts`   | `StemSplitJobData { songId, videoId, youtubeUrl, traceId }`, `PitchAnalysisJobData { songId, vocalStemKey, traceId }`                                                     |
| `src/jobs/adapters/stemsplit.interface.ts`    | `StemSplitAdapter` interface: `createJob(youtubeUrl): Promise<string>`, `downloadStem(downloadUrl): Promise<Buffer>`                                                      |
| `src/jobs/adapters/stemsplit.service.ts`      | HTTP adapter using `fetch`. POST to StemSplit API with `{ youtubeUrl, outputFormat: 'MP3', quality: 'BEST' }`. Bearer auth. Webhooks registered separately via dashboard. |
| `src/jobs/processors/stem-split.processor.ts` | `@Processor('stem-split')`: calls StemSplit API, updates song status to SPLITTING, saves externalJobId. 3 retries exponential backoff. On error: FAILED + errorMessage.   |
| `src/jobs/jobs.service.ts`                    | Queue producers: `enqueueStemSplit(data)`, `enqueuePitchAnalysis(data)` with retry config `{ attempts: 3, backoff: { type: 'exponential', delay: 5000 } }`                |

**Modify:** `src/jobs/jobs.module.ts` — Register BullMQ queues (`stem-split`, `pitch-analysis`), wire processors/services

**Modify:** `src/app.module.ts` — Add `BullModule.forRootAsync()` with REDIS_URL config (shared Redis connection for all queues)

**Tests:**

- Unit: JobsService — mock Queue, verify `add()` with correct data/options
- Unit: StemSplitProcessor — mock StemSplitService + PrismaService, verify status transitions
- Unit: StemSplitService — mock fetch, verify API calls
- Test idempotency: running processor twice doesn't duplicate state

---

## Phase 5: Songs Module ✅ COMPLETE

**Create (5 files):**

| File                                 | Contents                                                                                                                                                                                    |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `src/songs/dto/create-song.dto.ts`   | `{ youtubeUrl }` with YouTube URL regex validation                                                                                                                                          |
| `src/songs/dto/song-response.dto.ts` | Response shape matching API docs (id, videoId, title, thumbnailUrl, duration, status, stems[], pitchData?)                                                                                  |
| `src/songs/utils/youtube.util.ts`    | `extractVideoId(url)` — handles youtube.com/watch, youtu.be, /shorts/, /embed/. `buildThumbnailUrl(videoId)`.                                                                               |
| `src/songs/songs.service.ts`         | Core logic (~130 lines): `createSong` (deduplicate by videoId + add to UserSongLibrary), `findAllByUser` (query UserSongLibrary, paginated), `findOne`, `removeFromLibrary`, `updateStatus` |
| `src/songs/songs.controller.ts`      | 4 endpoints                                                                                                                                                                                 |

**Modify:** `src/songs/songs.module.ts` — Import JobsModule, wire controller/service, export SongsService

**Song deduplication logic (in `createSong`):**

1. Extract `videoId` from URL
2. Check if song with `videoId` exists in DB
3. **Cache hit + READY**: Add to user's library via `UserSongLibrary`, return existing song
4. **Cache hit + FAILED**: Reset to QUEUED, clear errorMessage, re-enqueue, add to library
5. **Cache hit + processing**: Add to library, return current status (client polls)
6. **Cache miss**: Create new Song record, add to UserSongLibrary, enqueue stem-split job

**Endpoints:**

- `POST /songs` (auth) — Submit YouTube URL, returns 202
- `GET /songs` (auth) — List user's library (via UserSongLibrary join), paginated
- `GET /songs/:id` (auth) — Get song with stems + pitch data
- `DELETE /songs/:id` (auth) — Remove from user's library (not delete song), returns 204

**Tests:**

- Unit: `extractVideoId` with all URL formats + invalid inputs
- Unit: SongsService — deduplication paths, pagination, library add/remove
- Integration: supertest on all 4 endpoints

---

## Phase 6: Stems Module ✅ COMPLETE

**Create (4 files):**

| File                                          | Contents                                                                                                                         |
| --------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `src/stems/dto/stem-response.dto.ts`          | `{ id, type, format, fileSize }`                                                                                                 |
| `src/stems/dto/presigned-url-response.dto.ts` | `{ url, expiresIn }`                                                                                                             |
| `src/stems/stems.service.ts`                  | `findBySongId`, `getPresignedUrl` (15min TTL via StorageService), `createStems` (batch create in $transaction, used by Webhooks) |
| `src/stems/stems.controller.ts`               | `GET /songs/:songId/stems`, `GET /songs/:songId/stems/:stemId/url`                                                               |

**Modify:** `src/stems/stems.module.ts` — Wire controller/service, export StemsService

**Tests:** Unit + integration on presigned URL generation, listing stems

---

## Phase 7: Webhooks Module ✅ COMPLETE

The critical integration point — receives StemSplit callbacks, downloads stems, uploads to R2, enqueues pitch analysis.

**Created (5 files):**

| File                                          | Contents                                                                                                                                                                                                                                               |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `src/webhooks/dto/stemsplit-webhook.dto.ts`   | `{ event ('job.completed'\|'job.failed'), timestamp, data: { jobId, status, input?, outputs?, error? } }` with class-validator decorators                                                                                                              |
| `src/webhooks/guards/webhook-secret.guard.ts` | Validates HMAC-SHA256 signature from `X-Webhook-Signature` header against `STEMSPLIT_WEBHOOK_SECRET` using raw request body                                                                                                                            |
| `src/webhooks/stem-download.service.ts`       | Downloads stems from StemSplit URLs, uploads to R2, maps stem types. Also enqueues pitch analysis for vocal stem.                                                                                                                                      |
| `src/webhooks/webhooks.service.ts`            | `handleStemSplitWebhook`: find song by externalJobId, if failed: mark FAILED. If completed: delegate to StemDownloadService → create Stem records → update status to ANALYZING → enqueue pitch-analysis job. Idempotent (skip if stems already exist). |
| `src/webhooks/webhooks.controller.ts`         | `POST /webhooks/stemsplit` — `@Public()` + `@UseGuards(WebhookSecretGuard)`, returns `{ received: true }`                                                                                                                                              |

**Modified:**

- `src/webhooks/webhooks.module.ts` — Import StemsModule, JobsModule, SongsModule; register StemDownloadService
- `src/jobs/jobs.module.ts` — Export STEMSPLIT_ADAPTER for use by WebhooksModule

**Tests (12 total):**

- Unit: completed webhook flow (download, upload, create records, enqueue) ✅
- Unit: failed webhook flow (mark FAILED) ✅
- Unit: idempotency (second webhook doesn't duplicate) ✅
- Unit: completed with no stems marks FAILED ✅
- Unit: WebhookSecretGuard (valid/invalid/missing — 3 tests) ✅
- Unit: StemDownloadService download/upload (2 tests) ✅
- Unit: StemDownloadService pitch enqueue with/without vocals (2 tests) ✅

---

## Phase 8: Sessions Module ✅ COMPLETE

**Create (4 files):**

| File                                       | Contents                                                                                                                           |
| ------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------- |
| `src/sessions/dto/create-session.dto.ts`   | `{ songId, duration, loopStart?, loopEnd?, speed?, overallScore (0-100), pitchLog[] { time, detectedHz, referenceHz, cents } }` ✅ |
| `src/sessions/dto/session-response.dto.ts` | Response shape (`SessionResponse` for lists, `SessionDetailResponse` with pitchLog for detail) ✅                                  |
| `src/sessions/sessions.service.ts`         | `create` (verify song exists + READY), `findAllByUser` (paginated), `findOne` (verify ownership) ✅                                |
| `src/sessions/sessions.controller.ts`      | `POST /sessions` (201), `GET /sessions`, `GET /sessions/:id` ✅                                                                    |

**Modify:** `src/sessions/sessions.module.ts` — Wire controller/service ✅

**Tests:** Unit: 9 tests (create READY/not found/not ready/default speed, list paginated/no pitchLog, findOne owner/not found/forbidden) ✅

---

## Phase 9: Health Checks ✅ COMPLETE

**Created (5 files):**

| File                                     | Contents                                                                                       |
| ---------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `src/health/health.module.ts`            | Module with TerminusModule + BullMQ queue registration                                         |
| `src/health/health.controller.ts`        | `GET /health` (Prisma + Redis ping), `GET /health/detailed` (+ queue stats) — both `@Public()` |
| `src/health/indicators/prisma.health.ts` | `PrismaHealthIndicator` — runs `$queryRawUnsafe('SELECT 1')`                                   |
| `src/health/indicators/redis.health.ts`  | `RedisHealthIndicator` — runs Redis PING via ioredis                                           |
| `src/health/queue-stats.service.ts`      | `QueueStatsService` — extracts queue depth/active/failed/delayed counts                        |

**Modified:** `src/app.module.ts` — Added `HealthModule` to imports

**Tests:** `src/health/health.controller.spec.ts` — 2 tests (basic check, detailed with queue stats)

---

## Phase 10: Integration Testing & Polish ✅ COMPLETE

**Create:**

- `src/test/test-utils.ts` — Helper to build NestJS testing module with mocks, JWT generator, test user factory
- `src/test/fixtures/songs.fixture.ts` — Song and stem fixtures (QUEUED, READY states, presigned URL)
- `src/test/fixtures/webhook.fixture.ts` — StemSplit webhook payloads (completed, failed)
- `test/app.e2e-spec.ts` — Full E2E flow covering all endpoints: auth (register, login, delete account), songs (create, list, get, delete), stems (list, presigned URL), webhooks (valid, missing/invalid secret), sessions (create, list, detail), health (basic, detailed)

**Modify:** `test/jest-e2e.json` — Added moduleNameMapper for `@/` path alias

**No changes needed:** `src/app.module.ts` — Already correctly wired with BullModule root, LoggerModule, HealthModule, env validation from previous phases

**Tests:** `test/app.e2e-spec.ts` — 23 e2e tests covering all API endpoints, request validation, auth guards, webhook security, and response shapes

---

## Phase 11: Documentation Updates ✅ COMPLETE

Updated all docs to reflect implementation decisions:

**Modified:** `docs/03-api-design.md`

- Updated `POST /songs` with deduplication behavior (existing READY → add to library, existing FAILED → re-queue, new → create + enqueue)
- Clarified `POST /songs` always returns 202 (flow diagram and endpoint docs)
- Updated `GET /songs` to clarify queries via UserSongLibrary
- Updated `GET /songs/:id` to note 404 if not in user's library
- Updated `DELETE /songs/:id` description (removes from library, not deletes song)
- Fixed response shapes: stems return `storageKey` (not `url`), pitchData returns `storageKey` (not `url`)
- Fixed ID format in examples from prefixed (`song_xyz`, `sess_abc`) to plain CUIDs
- Added `traceId` field to error response format

**Modified:** `docs/02-architecture.md`

- Fixed ID format rule: plain CUIDs (no type prefix), matching Prisma `@default(cuid())`
- Updated Module Boundary Rules with actual module names and cross-module dependencies (SongsModule → JobsModule, WebhooksModule → StemsModule + JobsModule)
- Added WebhookSecretGuard and global modules note

**Verified (already up to date):** `docs/04-data-models.md`

- UserSongLibrary model was already documented with fields, constraints, and relations
- Song model already shows `userId` as "Original submitter"
- Dedup strategy already documented in schema comments

**Verified (already up to date):** `docs/12-code-quality.md`

- Zod env validation approach was already documented (line 86)
- TraceIdInterceptor pattern was already documented (line 87)

---

## Files Summary

### New files: ~43

- Common: 8 (config, decorators, guards, filters, interceptors, pipes, dto)
- Auth: 12 (strategy, 6 DTOs, 2 providers + interface, service, controller)
- Storage: 2 (interface, service)
- Jobs: 5 (interfaces, adapter interface + service, processor, service)
- Songs: 5 (2 DTOs, util, service, controller)
- Stems: 4 (2 DTOs, service, controller)
- Webhooks: 4 (DTO, guard, service, controller)
- Sessions: 4 (2 DTOs, service, controller)
- Health: 4 (module, controller, 2 indicators)
- Tests: ~5 (utils, fixtures, e2e)

### Modified files: ~11

- `prisma/schema.prisma` (add UserSongLibrary)
- `packages/shared/src/types.ts` (add UserSongLibrary interface)
- `src/main.ts` (logger, global guards/filters/interceptors)
- `src/app.module.ts` (env validation, LoggerModule, BullModule root, HealthModule)
- `src/prisma/prisma.service.ts` (slow query middleware)
- 7 module files (auth, songs, stems, sessions, jobs, webhooks, storage)
- `.env.example` (add JWT_REFRESH_EXPIRATION)

---

## Verification ✅ ALL PASSED

1. **Unit tests**: `cd apps/api && pnpm test` — ✅ 92 tests, 15 suites, all passing
2. **Lint**: `cd apps/api && pnpm lint` — ✅ zero warnings
3. **Build**: `cd apps/api && pnpm build` — ✅ compiles cleanly
4. **Docker**: image builds successfully — ✅ 621MB image
5. **Production deployment**:
   - PostgreSQL + Redis containers — ✅ running
   - `prisma migrate deploy` — ✅ 2 migrations applied (init + update_stem_type_enum)
   - Nest application started — ✅ all routes mapped
   - `GET /v1/health` — ✅ `{"status":"ok"}`, database up, redis up
   - `POST /v1/auth/register` — ✅ user created, JWT tokens returned
   - `POST /v1/songs` with YouTube URL — ✅ returns 202, song QUEUED
   - TLS certs provisioned — ✅
6. **E2E test**: `cd apps/api && pnpm test:e2e` — ✅ 23 tests, all passing

**Total: 115 tests (92 unit + 23 e2e), lint clean, build clean, deployed and verified on production.**
