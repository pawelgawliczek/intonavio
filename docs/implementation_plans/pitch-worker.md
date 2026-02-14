# Intonavio Pitch Worker — Implementation Plan

## Context

The Backend (Phase 1) is complete. The NestJS API already enqueues `PitchAnalysisJobData` jobs (`{ songId, vocalStemKey, traceId }`) to the `pitch-analysis` BullMQ queue after stems are downloaded. The Python worker scaffolding exists at `workers/pitch-analyzer/` with stub files (`worker.py`, `analyzer.py`, `storage.py`, `db.py`), a working Dockerfile, pinned dependencies, and tooling config (ruff, mypy strict, pytest with 80% coverage threshold).

This plan implements the worker that consumes those jobs, runs pYIN pitch extraction, uploads results to R2, and marks songs as READY.

---

## File Structure After Implementation

```
workers/pitch-analyzer/
  src/
    __init__.py             (exists, keep empty)
    config.py               NEW — env validation via pydantic-settings
    logger.py               NEW — structured JSON logger
    models.py               NEW — Pydantic models (job data, output, stats)
    consumer.py             NEW — BullMQ Worker wrapper + heartbeat
    storage.py              REPLACE stub — R2 download/upload via boto3
    db.py                   REPLACE stub — psycopg2 transaction operations
    analyzer.py             REPLACE stub — pYIN extraction pipeline
    worker.py               REPLACE stub — job orchestrator + main()
  requirements.txt          MODIFY — add bullmq, pydantic-settings
  requirements-dev.txt      MODIFY — add soundfile
  Dockerfile                NO CHANGES
  pyproject.toml            NO CHANGES
```

---

## Phase 1: Configuration, Logging, and Models

Everything depends on this phase.

### 1.1 Update `requirements.txt`

Add `bullmq` (official Python BullMQ client from Taskforce.sh — speaks same Redis protocol as Node.js BullMQ) and `pydantic-settings` for env-based config.

Final contents:

```
librosa==0.10.2.post1
numpy==1.26.4
boto3==1.35.74
psycopg2-binary==2.9.10
redis==5.2.1
pydantic==2.10.3
pydantic-settings==2.7.0
bullmq==2.7.5
```

Update `requirements-dev.txt` — add `soundfile==0.12.1` for test audio generation.

### 1.2 Create `src/config.py` — Environment Configuration

`pydantic-settings` `BaseSettings` that validates all env vars at startup, fails fast on missing values.

**Required vars:** `REDIS_URL`, `DATABASE_URL`, `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET_NAME`

**Configurable with defaults:** `pyin_fmin=65.0`, `pyin_fmax=2093.0`, `pyin_hop_length=512`, `pyin_sample_rate=44100`, `max_unvoiced_ratio=0.9`, `heartbeat_interval_seconds=60`, `queue_name="pitch-analysis"`

### 1.3 Create `src/logger.py` — Structured JSON Logger

Custom `JsonFormatter` on Python's `logging` module that emits JSON to stdout with mandatory fields: `level`, `timestamp`, `service` ("pitch-worker"), `module`, `message`.

Helper `log_with_context(logger, level, message, **kwargs)` merges keyword args (traceId, songId, durationMs, etc.) as top-level JSON fields.

### 1.4 Create `src/models.py` — Pydantic Models

| Model                  | Purpose                                                                                                                                |
| ---------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `PitchAnalysisJobData` | Parses camelCase BullMQ job data (`songId`, `vocalStemKey`, `traceId`)                                                                 |
| `PitchFrame`           | Single frame: `t`, `hz` (nullable), `midi` (nullable), `voiced`, `rms` (nullable)                                                      |
| `PitchAnalysisOutput`  | Full output JSON with `songId`, `sampleRate`, `hopSize`, `hopDuration`, `frameCount`, `frames[]` — serializes to camelCase via aliases |
| `AnalysisStats`        | Internal: `frame_count`, `voiced_frame_count`, `voiced_frame_percent`, `frequency_min`, `frequency_max`, `is_valid`                    |

---

## Phase 2: BullMQ Consumer

### 2.1 Create `src/consumer.py` — BullMQ Worker Wrapper

Uses the `bullmq` Python package `Worker` class. Accepts a job handler callback (injected, keeps consumer decoupled from business logic). Includes `run_heartbeat()` async loop that logs every 60s.

The handler raises exceptions on failure — BullMQ handles retry logic (3 attempts, exponential backoff, configured by the NestJS producer).

---

## Phase 3: R2 Storage Adapter

### 3.1 Implement `src/storage.py` — R2 Operations (replace stub)

Stateless functions taking S3 client + bucket as params (testable via mock injection):

- `create_s3_client(config) -> S3Client` — boto3 client configured for R2 endpoint
- `download_stem(client, bucket, key, trace_id) -> bytes` — GET object, return raw bytes, log duration
- `upload_pitch_json(client, bucket, key, json_bytes, trace_id) -> None` — PUT with `Content-Type: application/json`, log duration

---

## Phase 4: Database Adapter

### 4.1 Implement `src/db.py` — PostgreSQL Operations (replace stub)

Uses `psycopg2` directly (no ORM). Two functions:

- `create_connection(config) -> connection` — from `DATABASE_URL`
- `complete_pitch_analysis(conn, song_id, storage_key, frame_count, hop_duration, trace_id) -> str` — single transaction:
  1. `INSERT INTO "PitchData" ... ON CONFLICT ("songId") DO UPDATE` (idempotent upsert)
  2. `UPDATE "Song" SET status = 'READY' WHERE id = %s AND status = 'ANALYZING'`

Uses quoted identifiers to match Prisma's generated table/column names. Connection created per-job, closed in `finally`.

---

## Phase 5: pYIN Analysis Pipeline

Core algorithmic module — requires 95% branch coverage.

### 5.1 Implement `src/analyzer.py` — pYIN Extraction (replace stub)

Four focused functions:

- **`hz_to_midi(hz) -> float`** — `69 + 12 * log2(hz / 440)`. Pure function.
- **`extract_pitch(audio_bytes, config, trace_id) -> (frames, stats)`** — loads audio via `librosa.load(BytesIO(audio_bytes), sr=44100, mono=True)`, runs `librosa.pyin(fmin=65, fmax=2093, hop_length=512)`, computes per-frame RMS via `librosa.feature.rms(y=audio, hop_length=512)`, logs params for reproducibility, warns if <10% voiced.
- **`build_frames(f0, voiced_flag, rms_values, sample_rate, hop_length) -> list[PitchFrame]`** — converts numpy arrays to PitchFrame list, handles NaN (unvoiced). Includes RMS energy per frame for client-side artifact filtering.
- **`validate_analysis(stats, max_unvoiced_ratio) -> bool`** — rejects if 0 frames or >90% unvoiced.

Key: frame is voiced only if `voiced_flag[i]` is True AND `f0[i]` is not NaN. MIDI rounded to 1 decimal, time to 4 decimals.

---

## Phase 6: Job Orchestrator

### 6.1 Implement `src/worker.py` — Main Entry Point (replace stub)

The `handle_job(job, config)` function is the complete job lifecycle:

1. Parse job data via `PitchAnalysisJobData.model_validate(job.data)`
2. Download vocal stem from R2 (`job_data.vocal_stem_key`)
3. Run `extract_pitch()` on audio bytes
4. Validate — raise `ValueError` if invalid (BullMQ retries)
5. Build `PitchAnalysisOutput`, serialize to JSON (camelCase)
6. Upload to R2 at `pitch/{songId}/reference.json`
7. Create PitchData record + update Song to READY in transaction

`main()` loads config, creates worker with handler wrapped in `run_in_executor` (librosa is CPU-bound, must not block the async event loop), starts heartbeat, waits for SIGINT.

---

## Phase 7: Testing

### 7.1 Create test infrastructure

`tests/__init__.py` (empty), `tests/conftest.py` with shared fixtures:

- `sample_config` — WorkerConfig with test values
- `sine_wave_bytes(frequency, duration)` — factory generating WAV bytes via soundfile
- `silence_bytes` — 2s of silence

### 7.2 `tests/test_analyzer.py` — Core Algorithm Tests (~17 tests)

| Test                               | Assertion                                  |
| ---------------------------------- | ------------------------------------------ |
| `test_hz_to_midi_440hz`            | Returns exactly 69.0                       |
| `test_hz_to_midi_261_63hz`         | Returns ~60.0 (C4)                         |
| `test_hz_to_midi_329_63hz`         | Returns ~64.0 (E4)                         |
| `test_hz_to_midi_880hz`            | Returns 81.0 (A5)                          |
| `test_extract_pitch_440hz_sine`    | Voiced frames hz within +/-1Hz of 440      |
| `test_extract_pitch_261hz_sine`    | Detection within +/-1Hz                    |
| `test_extract_pitch_silence`       | All frames unvoiced                        |
| `test_extract_pitch_frame_count`   | Matches `ceil(duration * sr / hop_length)` |
| `test_build_frames_with_nan`       | NaN f0 -> unvoiced                         |
| `test_build_frames_time_monotonic` | t values monotonically increasing          |
| `test_compute_stats_all_voiced`    | 100% voiced                                |
| `test_compute_stats_all_unvoiced`  | 0% voiced, is_valid=False                  |
| `test_compute_stats_mixed`         | Correct percentages                        |
| `test_validate_analysis_valid`     | 50% voiced, threshold 0.9 -> True          |
| `test_validate_analysis_rejected`  | 5% voiced -> False                         |
| `test_validate_analysis_empty`     | 0 frames -> False                          |
| `test_extract_pitch_idempotent`    | Same input twice = identical output        |

### 7.3 `tests/test_models.py` — Pydantic Validation (~6 tests)

Parse camelCase job data, missing fields raise ValidationError, output serializes to camelCase, schema matches spec.

### 7.4 `tests/test_storage.py` — R2 Adapter (~5 tests, mocked boto3)

Download success/not-found, upload content-type, correct keys, client endpoint.

### 7.5 `tests/test_db.py` — Database Adapter (~5 tests, mocked psycopg2)

INSERT + UPDATE executed, idempotent upsert, WHERE clause guards status, transaction used, returns ID.

### 7.6 `tests/test_worker.py` — Orchestrator Integration (~6 tests, all externals mocked)

Success path, validation failure raises ValueError, S3 error propagates, DB error propagates, idempotent re-run, camelCase parsing.

### 7.7 `tests/test_config.py` — Config Validation (~3 tests)

All vars set loads OK, missing required raises, defaults correct.

---

## Phase 8: Final Verification

No file changes — verification only.

### Quality Gates

1. `ruff check src/ tests/` — no warnings
2. `ruff format --check src/ tests/` — formatted
3. `mypy src/` — strict mode, no errors
4. `pytest --cov=src --cov-report=term-missing --cov-fail-under=80` — passes
5. 95% branch coverage on `src/analyzer.py`
6. No `print()` in `src/`
7. No hardcoded secrets
8. All functions have type hints
9. Max 40 lines/function, 300 lines/file
10. Exact dependency versions pinned

### End-to-End Verification

1. `docker build -f workers/pitch-analyzer/Dockerfile .` succeeds
2. Worker starts, emits structured startup log
3. Heartbeat appears every 60s
4. Submit song via API -> stems complete -> pitch analysis job consumed -> vocal stem downloaded -> pYIN extraction logged -> pitch JSON uploaded to R2 -> PitchData record created -> Song status READY
5. Re-enqueue same job -> idempotent, no errors, same result
6. Song with no usable audio -> job fails with descriptive error, Song status FAILED after 3 retries

---

## Dependency Graph

```
Phase 1 (Config, Logger, Models)
   |
   +--> Phase 2 (BullMQ Consumer)
   +--> Phase 3 (R2 Storage)
   +--> Phase 4 (Database)
   +--> Phase 5 (pYIN Analyzer)
            |
            v
        Phase 6 (Job Orchestrator) <-- depends on 1-5
            |
            v
        Phase 7 (Testing) <-- depends on 1-6
            |
            v
        Phase 8 (Verification)
```

Phases 2-5 can be implemented in parallel after Phase 1.

---

## Key Reference Files (read-only, do not modify)

| File                                                   | Purpose                                                                     |
| ------------------------------------------------------ | --------------------------------------------------------------------------- |
| `apps/api/src/jobs/interfaces/job-data.interface.ts`   | Source of truth for `PitchAnalysisJobData` shape                            |
| `apps/api/src/jobs/jobs.service.ts`                    | How jobs are enqueued (queue name `pitch-analysis`, job name `analyze`)     |
| `apps/api/src/jobs/processors/stem-split.processor.ts` | Reference pattern for BullMQ processor (lifecycle, logging, error handling) |
| `apps/api/src/storage/storage.service.ts`              | R2 adapter pattern (endpoint URL, bucket, credentials)                      |
| `apps/api/src/webhooks/stem-download.service.ts:61`    | Where pitch analysis jobs are enqueued (after stem download)                |
| `apps/api/prisma/schema.prisma`                        | PitchData model and Song status enum                                        |
