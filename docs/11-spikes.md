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

1. Create a minimal Node.js script that calls the StemSplit API
2. Submit 5 diverse YouTube URLs (pop, rock, ballad, hip-hop, classical)
3. Use 6-stem split mode (`SIX_STEMS`) with MP3 output
4. Measure processing time for each
5. Download stems and evaluate quality (vocals isolation, artifact levels)
6. Test webhook delivery reliability
7. Calculate cost per song

### Test Songs

| #   | Genre    | Duration | YouTube URL             | Notes                       |
| --- | -------- | -------- | ----------------------- | --------------------------- |
| 1   | Pop      | ~3:30    | (selected at test time) | Clean studio production     |
| 2   | Rock     | ~4:00    | (selected at test time) | Heavy instrumentation       |
| 3   | Ballad   | ~4:30    | (selected at test time) | Vocal-forward mix           |
| 4   | Hip-hop  | ~3:00    | (selected at test time) | Rap vocals + beat           |
| 5   | Acoustic | ~3:00    | (selected at test time) | Guitar + voice, minimal mix |

### Success Criteria

| Metric                  | Target                           | How to Measure                                      |
| ----------------------- | -------------------------------- | --------------------------------------------------- |
| Vocal isolation quality | Minimal bleed, clear vocals      | Subjective listening test (1-5 scale, target ≥ 3.5) |
| Instrumental quality    | Vocals removed cleanly           | Subjective listening test                           |
| Processing time         | < 5 min for a 4-min song         | Measure webhook arrival time                        |
| Webhook reliability     | 5/5 webhooks received            | Count received callbacks                            |
| API uptime              | No errors during test            | Monitor HTTP responses                              |
| Cost per song           | ≤ $0.50 for typical 3-4 min song | Calculate from API pricing                          |

### Risks

- **Quality variation**: Stem quality may vary significantly by genre or mix complexity → test diverse genres
- **API downtime**: StemSplit is a third-party service → evaluate SLA, consider fallback (e.g., Demucs self-hosted)
- **Webhook reliability**: Webhooks may fail or be delayed → implement polling fallback
- **Cost at scale**: $0.10/min adds up — a 5-min song costs $0.50, which may require careful user-facing pricing

### Deliverables

- Quality assessment spreadsheet (per song, per stem type)
- Processing time measurements
- Cost analysis with projections at 100/1K/10K songs per month
- Webhook reliability report
- Recommendation: proceed with StemSplit, negotiate pricing, or evaluate self-hosted Demucs as alternative

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
