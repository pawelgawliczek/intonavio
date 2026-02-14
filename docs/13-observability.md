# Intonavio — Observability & Debugging

## Correlation IDs

Every song submission generates a `traceId` that follows the request across all services:

```
Client → API (traceId in response header)
       → BullMQ job (traceId in job data)
       → StemSplit webhook (traceId in metadata)
       → Python worker (traceId in log context)
       → R2 upload (traceId in object metadata)
```

Every log line includes `traceId` + the relevant resource ID (`songId`, `exerciseId`, `userId`). You can grep a single ID and see the entire lifecycle from submission to READY/FAILED.

## Structured Logging

Every log entry is JSON with mandatory fields:

```json
{
  "level": "error",
  "timestamp": "2025-06-01T12:00:00.123Z",
  "service": "api",
  "traceId": "trc_abc123",
  "songId": "song_xyz789",
  "module": "StemSplitService",
  "message": "Stem download failed",
  "error": { "code": "ECONNRESET", "attempt": 2 },
  "durationMs": 3400
}
```

| Field                              | Required        | Why                                                   |
| ---------------------------------- | --------------- | ----------------------------------------------------- |
| `traceId`                          | Yes             | Cross-service correlation                             |
| `songId` / `exerciseId` / `userId` | When applicable | Filter logs per resource                              |
| `module`                           | Yes             | Where in the code                                     |
| `durationMs`                       | For operations  | Spot slow queries, slow API calls, slow processing    |
| `error`                            | On failures     | Structured error with code, not just a message string |

## Per-Layer Debugging

### API (NestJS)

- Request/response interceptor logs: method, path, status, duration, userId for every request. Exclude body for large payloads (pitch logs), include body for mutations (POST/PUT/DELETE).
- Slow query warning: Prisma middleware logs any query taking >100ms.
- Failed auth attempts logged with IP and reason (expired token, invalid signature, missing header).

### Job Queue (BullMQ)

- Log on every state transition: `job.created`, `job.active`, `job.completed`, `job.failed`, `job.retrying`.
- Include `jobId`, `traceId`, `songId`, `attempt`, `durationMs` in every log.
- On failure: log the full error + which attempt it was + whether it will retry or give up.
- Stalled job detection: BullMQ's built-in stall check with alerting. A stalled job means the worker crashed mid-processing.

### Python Worker

- Structured JSON logging to stdout with mandatory fields: `level`, `timestamp`, `service` ("pitch-worker"), `module`, `message`.
- Every log line includes `traceId` and `songId` for cross-service correlation.
- Log pYIN parameters used (`fmin`, `fmax`, `hopLength`, `sampleRate`) for every analysis — reproducible locally with same params.
- Log output stats after analysis: `frameCount`, `voicedFramePercent`, `frequencyMin`, `frequencyMax`. If `voicedFramePercent < 10%`, log a warning (bad audio).
- Log R2 operations with `key`, `sizeBytes`, `durationMs` for both stem download and pitch JSON upload.
- Log DB persistence with `pitchDataId`, `songId`, `durationMs`.
- Log job lifecycle: `Job started` (with traceId, songId), `Job completed` (with durationMs), `Job failed` (with error, attempt info).
- Heartbeat every 60s: `{"message": "heartbeat", "status": "alive"}` for health monitoring.
- BullMQ lock duration set to 5 minutes (pYIN extraction takes ~110s on a typical song).
- Debug mode (env flag, disabled in production): save intermediate numpy arrays to a debug path for reproducing pitch extraction issues locally.

### iOS Client

- Pitch detection debug mode (dev settings toggle): records raw mic input + detected frequencies + reference lookup to a local file. When a user reports "scoring feels wrong", export this file for analysis.
- YouTube sync drift log: every sync correction (drift > 150ms) logged with `ytTime`, `stemTime`, `correction` to reveal patterns. In debug builds, every drift sample (corrected or not) is logged.
- Audio route change log: when AirPods or other audio devices connect/disconnect, the route change reason is logged and stems are re-synced. Look for "Audio route changed" and "Re-synced stems after audio route change" entries.
- Network request log in debug builds: all API calls with status, duration, response size.

### Web Client

- AudioWorklet errors forwarded to main thread and logged to error reporting. Worklets fail silently by default — explicit forwarding required.
- `performance.mark()` / `performance.measure()` around pitch detection cycle for Chrome DevTools profiling.
- Canvas rendering frame drops: if piano roll drops below 30fps, log a warning with the frame time.

## Health Checks

Every service exposes a health endpoint:

| Service       | Endpoint                   | Checks                                                |
| ------------- | -------------------------- | ----------------------------------------------------- |
| API           | `GET /health`              | PostgreSQL connection, Redis ping, R2 reachable       |
| API           | `GET /health/detailed`     | Queue depth, failed job count, oldest pending job age |
| Python Worker | stdout heartbeat every 60s | Process alive, Redis connected, R2 reachable          |
| Web           | `GET /api/health`          | API reachable from Next.js server                     |

## Debug Reproducibility

For the hardest bugs, ensure reproduction outside the live app:

| Problem               | Debug Artifact                                 | How to Reproduce                                  |
| --------------------- | ---------------------------------------------- | ------------------------------------------------- |
| Wrong pitch detection | Raw audio recording + detected frequencies log | Feed recording into YIN unit test, compare output |
| Wrong scoring         | Session `pitchLog` JSON                        | Re-run scoring function on the saved pitchLog     |
| Bad reference pitch   | Vocal stem file + pYIN params from log         | Run pYIN locally with same params, inspect output |
| YouTube sync drift    | Drift correction log                           | Analyze timing pattern, check if video-specific   |
| StemSplit failure     | Request/response log with traceId              | Replay the exact API call                         |

## Error Reporting

- **API + Worker**: Sentry with `traceId` as a tag. Group by error type, not by message string.
- **iOS**: Sentry iOS SDK. Breadcrumbs include last 5 API calls + last audio session state.
- **Web**: Sentry browser SDK. Capture AudioWorklet errors explicitly (they don't bubble to `window.onerror`).
- Every Sentry event includes `traceId`, `userId`, and the relevant resource ID. An error without context is useless.
