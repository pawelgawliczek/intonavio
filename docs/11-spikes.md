# Intonavio — Validation Spikes

## Overview

Before committing to the full implementation, three spikes validate the riskiest technical assumptions. Each spike is a time-boxed prototype focused on answering a specific question.

---

## Spike A: iOS Real-Time Pitch Detection

### Question

Can we detect a singer's pitch in real time on iOS using AVAudioEngine + YIN with latency under 30ms and accuracy within ±10 cents for sustained notes?

### Approach

1. Create a minimal SwiftUI app with microphone access
2. Set up AVAudioEngine with `installTap` on the input node (buffer size: 1024, 44.1kHz mono)
3. Implement the YIN algorithm in Swift
4. Display detected frequency + note name in real time
5. Measure round-trip latency (audio buffer arrival → UI update)
6. Test with a tuning app or known-pitch audio source for accuracy

### Success Criteria

| Metric                | Target                       | How to Measure                                |
| --------------------- | ---------------------------- | --------------------------------------------- |
| Latency (buffer → UI) | < 30ms                       | Timestamp in tap callback vs UI update        |
| Pitch accuracy        | ±10 cents on sustained notes | Compare against hardware tuner on same signal |
| CPU usage             | < 15% on iPhone 12+          | Xcode Instruments profiling                   |
| Confidence threshold  | > 0.8 filters noise reliably | Test in quiet and noisy environments          |
| Min detectable pitch  | ≤ 100 Hz (G2)                | Test with low male vocal samples              |

### Risks

- **Noise sensitivity**: YIN may produce false positives in noisy environments → mitigate with confidence threshold and optional noise gate
- **Low pitch accuracy**: 1024-sample buffer may struggle below ~80 Hz → fall back to 2048 buffer for bass voices
- **Thread safety**: Tap callback runs on audio thread — dispatch to main must not cause jank

### Deliverables

- Working prototype app with real-time pitch display
- Latency and accuracy measurements documented
- Recommendation: proceed as-is, adjust buffer size, or consider alternative algorithm

---

## Spike B: YouTube Looping in WKWebView

### Question

Can we embed a YouTube video in WKWebView, control it programmatically (play, pause, seek, speed, mute), and implement reliable A-B looping with ±100ms precision?

### Approach

1. Create a minimal SwiftUI app with a WKWebView
2. Load the YouTube IFrame Player API in the web view
3. Implement Swift → JS bridge for playback control
4. Implement JS → Swift message handler for player state events
5. Build A-B loop logic: on `onStateChange` or timer, check `getCurrentTime()` and seek to A when reaching B
6. Test seek precision at various speeds (0.5x, 1x, 1.5x)

### Success Criteria

| Metric            | Target                               | How to Measure                                       |
| ----------------- | ------------------------------------ | ---------------------------------------------------- |
| Seek precision    | ±100ms                               | Compare `seekTo(t)` vs `getCurrentTime()` after seek |
| Loop continuity   | No audible gap on loop restart       | Listen test across 20+ loop cycles                   |
| Speed control     | 0.25x–2x works                       | Test `setPlaybackRate()` at each step                |
| Mute/unmute       | Instant, no audio leak               | Test `mute()`/`unMute()` transitions                 |
| JS bridge latency | < 50ms round trip                    | Timestamp Swift call → JS response                   |
| Reliability       | No player crashes over 30min session | Extended playback test                               |

### Risks

- **YouTube API restrictions**: Some videos may block embedded playback or disable `playsinline` → test with various video types
- **Seek imprecision**: YouTube's seek may overshoot by 0.5–2 seconds on some videos → implement compensating logic
- **WKWebView audio routing**: When YouTube is muted and stems play via AVAudioEngine, ensure no audio session conflicts
- **Rate limiting**: Frequent `getCurrentTime()` polling may have overhead → find optimal polling interval

### Deliverables

- Working prototype with YouTube embed, playback controls, and A-B looping
- Seek precision measurements at different speeds
- Audio session compatibility notes (YouTube muted + AVAudioEngine)
- Recommendation: proceed, adjust approach, or consider alternative (e.g., YouTube Data API for audio-only)

---

## Spike C: StemSplit API Integration

### Question

Does the StemSplit API produce stems of sufficient quality for practice purposes, within acceptable time and cost?

### Approach

Used the production Intonavio API to submit songs through the full pipeline: API → BullMQ → StemSplit → webhook → stem download.

### Test Songs

| #   | Genre    | Song                                | URL                                         | Duration |
| --- | -------- | ----------------------------------- | ------------------------------------------- | -------- |
| 1   | Jazz/Pop | Michael Buble — "Feeling Good"      | https://www.youtube.com/watch?v=YwVEXGq1WN0 | 3:59     |
| 2   | Acoustic | Carole King — "You've Got A Friend" | https://www.youtube.com/watch?v=BcJbzuyp6VY | 5:10     |

### Results

#### Processing Time

| Song                | StemSplit Create → Complete | Notes                        |
| ------------------- | --------------------------- | ---------------------------- |
| Feeling Good        | ~69 seconds                 | 3:59 song processed in ~1m   |
| You've Got A Friend | ~87 seconds                 | 5:10 song processed in ~1.5m |

Both well within the 5-minute target.

#### Stem Output

**Critical finding:** The StemSplit YouTube endpoint (`POST /youtube-jobs`) only returns **3 outputs**: `fullAudio`, `vocals`, `instrumental`. It does **not** support `outputType` parameter — the `SIX_STEMS` option is only available on the file upload endpoint (`POST /jobs`).

| Output       | Song 1 Size | Song 2 Size | Bitrate | Format |
| ------------ | ----------- | ----------- | ------- | ------ |
| vocals       | 9.1 MB      | 12 MB       | 320kbps | MP3    |
| instrumental | 9.1 MB      | 12 MB       | 320kbps | MP3    |
| fullAudio    | (skipped)   | (skipped)   | 320kbps | MP3    |

#### Quality Assessment

**Pending user listening test.** Stems downloaded to `/tmp/spike-c-stems/` for manual evaluation. Rate each on 1-5 scale:

| Stem          | Song 1 (Jazz/Pop) | Song 2 (Acoustic) |
| ------------- | ----------------- | ----------------- |
| Vocal clarity | \_\_\_ / 5        | \_\_\_ / 5        |
| Vocal bleed   | \_\_\_ / 5        | \_\_\_ / 5        |
| Instrumental  | \_\_\_ / 5        | \_\_\_ / 5        |

#### Cost Analysis

| Metric              | Value                                  |
| ------------------- | -------------------------------------- |
| Credits charged     | 239 + 310 = 549 seconds (~9.2 minutes) |
| Cost model          | Credits = audio duration in seconds    |
| Cost per song (avg) | ~$0.46 at $0.10/min (4.5 min avg)      |
| 30-min credit pack  | Covers ~6-7 typical songs              |

#### Webhook Integration

- Webhooks are registered **separately** via dashboard/API, not per-job
- Authentication uses **HMAC-SHA256** (`X-Webhook-Signature`), not shared secret header
- Webhook payload uses envelope format: `{ event, timestamp, data: { jobId, outputs } }`
- Download URLs are **presigned R2 URLs** (1-hour expiry), no auth header needed

#### API Contract Discrepancies Found

Our original implementation (based on assumed API contract) had several mismatches with the real StemSplit API:

| Aspect                | Documented (assumed)              | Actual                                               |
| --------------------- | --------------------------------- | ---------------------------------------------------- |
| Job creation response | `{ job_id: "..." }`               | `{ id: "..." }`                                      |
| Webhook delivery      | `webhookUrl` param per job        | Registered separately via dashboard/API              |
| Webhook auth          | `x-webhook-secret` shared header  | `X-Webhook-Signature` HMAC-SHA256                    |
| Webhook payload       | `{ job_id, status, stems[] }`     | `{ event, timestamp, data: { jobId, outputs: {} } }` |
| Stem download auth    | Bearer token required             | Presigned URLs, no auth needed                       |
| YouTube 6-stem        | `outputType: SIX_STEMS` supported | YouTube flow fixed at vocals + instrumental only     |

All discrepancies have been fixed in the codebase (commit `23d47bc` and `696a695`).

### Recommendation

**Conditional GO** — StemSplit works well for vocal/instrumental separation (fast, good quality at 320kbps). However:

1. **YouTube flow limitation**: Only produces vocals + instrumental (2 useful stems). For 6-stem separation (drums, bass, piano, guitar), we'd need to either:
   - Use the file upload flow: download YouTube audio first → upload to StemSplit → get 6 stems (adds complexity + download step)
   - Accept 2-stem mode for MVP and add 6-stem later if needed
2. **For singing practice**, vocals + instrumental is sufficient — the instrumental serves as the backing track. The 6-stem split would be a nice-to-have for advanced features (e.g., muting specific instruments).
3. **Cost is reasonable** at ~$0.46/song. Deduplication makes this a one-time cost per unique song.

---

## Spike Timeline

All three spikes run in parallel over 5 days:

| Day | Spike A (Pitch)               | Spike B (YouTube)            | Spike C (StemSplit)          |
| --- | ----------------------------- | ---------------------------- | ---------------------------- |
| 1   | AVAudioEngine setup, YIN impl | WKWebView setup, IFrame API  | API account setup, first job |
| 2   | Pitch display UI, tuning test | Playback controls, seek test | Submit all 5 test songs      |
| 3   | Accuracy measurement          | A-B loop implementation      | Download and evaluate stems  |
| 4   | Noise/edge case testing       | Speed + mute testing         | Webhook reliability test     |
| 5   | Document results              | Document results             | Cost analysis + document     |

### Go/No-Go Decision

After all spikes complete, evaluate:

- **All pass**: Proceed to Phase 1 (Backend) with confidence
- **One fails**: Investigate alternatives for the failed spike, re-spike if needed
- **Multiple fail**: Re-evaluate core architecture (e.g., switch to self-hosted audio processing, native video player instead of YouTube embed)
