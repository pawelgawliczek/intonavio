# YIN Algorithm Comparison: Real-time iOS vs Offline pYIN

**Date**: 2026-02-28
**Song**: "Feeling Good" (cmlkprw8y0007mh01gcwzvozs) — vocal stem, 238s

## Algorithms Compared

| Parameter            | iOS YIN (real-time)        | Offline pYIN (librosa)            |
| -------------------- | -------------------------- | --------------------------------- |
| Algorithm            | Pure YIN (Accelerate vDSP) | Probabilistic YIN (HMM smoothing) |
| Sample rate          | 44,100 Hz                  | 44,100 Hz                         |
| Analysis window      | 2,048 samples (46.4 ms)    | N/A (internal)                    |
| Hop size             | 256 samples (5.8 ms)       | 512 samples (11.6 ms)             |
| YIN threshold        | 0.10                       | N/A (HMM-based)                   |
| Confidence threshold | 0.85                       | N/A (HMM-based)                   |
| Frequency range      | 80–1,100 Hz                | 65–2,093 Hz                       |
| RMS noise floor      | 0.01 (was) / 0.005 (now)   | None                              |

## Results (before tuning, RMS = 0.01)

### Sanity Check: Local pYIN vs Stored Reference

- **100% match, 0.0 semitone difference** — offline pYIN is deterministic

### iOS YIN vs Stored Reference

| Metric                                   | Value                   |
| ---------------------------------------- | ----------------------- |
| Voiced frame match rate                  | 76.4% (9,832 / 12,863)  |
| Pitch accuracy (within ±1 semitone)      | 92.2% of matched        |
| Median pitch difference                  | 0.17 semitones          |
| Mean pitch difference                    | 0.63 semitones (7.7 Hz) |
| 95th percentile difference               | 1.39 semitones          |
| Missed (ref voiced, iOS silent)          | 3,031 (23.6%)           |
| False positives (iOS voiced, ref silent) | 277                     |

## Root Cause: Why iOS YIN Misses Frames

| Rejection reason        | Frames lost | % of ref voiced |
| ----------------------- | ----------- | --------------- |
| RMS noise gate (< 0.01) | 2,569       | 20.0%           |
| Low confidence (< 0.85) | 804         | 6.3%            |
| No YIN detection (tau)  | 128         | 1.0%            |

The RMS noise floor was the dominant source of missed frames — quiet vocal moments that pYIN captures but the noise gate silenced.

### Confidence Distribution (of frames where YIN found a pitch)

| Threshold | % of detections above |
| --------- | --------------------- |
| >= 0.50   | 100.0%                |
| >= 0.70   | 97.5%                 |
| >= 0.75   | 96.5%                 |
| >= 0.80   | 94.7%                 |
| >= 0.85   | 92.1%                 |
| >= 0.90   | 87.2%                 |

## Threshold Sweep

| Config                                        | Match%    | Accuracy  | Median diff | P95 diff    | False pos |
| --------------------------------------------- | --------- | --------- | ----------- | ----------- | --------- |
| **Original** (YIN 0.10, conf 0.85, RMS 0.01)  | 76.4%     | 92.2%     | 0.17 st     | 1.39 st     | 277       |
| Lower conf 0.80                               | 77.9%     | 91.3%     | 0.18 st     | 1.57 st     | 406       |
| Lower conf 0.75                               | 78.9%     | 90.6%     | 0.18 st     | 1.71 st     | 505       |
| YIN 0.15                                      | 76.4%     | 92.5%     | 0.17 st     | 1.29 st     | 277       |
| YIN 0.15 + conf 0.80                          | 77.9%     | 91.5%     | 0.18 st     | 1.47 st     | 406       |
| YIN 0.20                                      | 75.8%     | 92.8%     | 0.17 st     | 1.22 st     | 259       |
| YIN 0.20 + conf 0.75                          | 78.9%     | 89.6%     | 0.19 st     | 1.81 st     | 505       |
| **RMS 0.005 (chosen)**                        | **78.7%** | **91.7%** | **0.18 st** | **1.49 st** | **300**   |
| All relaxed (YIN 0.20, conf 0.75, RMS 0.005)  | 82.4%     | 88.9%     | 0.19 st     | 2.13 st     | 594       |
| Sweet spot A (YIN 0.15, conf 0.78, RMS 0.008) | 79.6%     | 91.0%     | 0.18 st     | 1.61 st     | 476       |
| Sweet spot B (YIN 0.18, conf 0.80, RMS 0.008) | 79.2%     | 90.8%     | 0.18 st     | 1.64 st     | 422       |

## Decision: Lower RMS Noise Floor to 0.005

Changed `PitchConstants.rmsNoiseFloor` from `0.01` (~-40 dB) to `0.005` (~-46 dB).

**Impact**:

- Match rate: 76.4% → 78.7% (+2.3%)
- Accuracy: 92.2% → 91.7% (negligible loss)
- False positives: 277 → 300 (+23, minimal)
- Picks up quiet vocal passages previously gated as silence

## Key Takeaways

1. **pYIN and YIN produce similar pitch values when both detect voice** — median difference is only 0.17 semitones.
2. **The algorithms differ mainly in voiced/unvoiced classification** — pYIN's HMM smoothing catches borderline frames that plain YIN + threshold gates reject.
3. **iOS YIN is intentionally conservative** — for real-time singing, false positives (phantom notes) are worse than missed frames.
4. **RMS noise floor is the biggest tuning lever** — it alone accounts for 20% of missed frames.
5. **The confidence threshold at 0.85 sits at a natural break point** — the confidence distribution shows a gradual falloff, so lowering it yields diminishing returns with more noise.

## Sample: Frame-by-frame comparison (6–30s)

```
   Time |   Ref Hz  Ref MIDI |  pYIN Hz pYIN MIDI |   iOS Hz  iOS MIDI
    6.0 |    113.8      45.6 |    113.8      45.6 |    116.9      46.0
    7.0 |    195.9      55.0 |    195.9      55.0 |    185.5      54.0
    7.5 |    229.0      57.7 |    229.0      57.7 |    227.8      57.6
    8.0 |    229.0      57.7 |    229.0      57.7 |    226.7      57.5
   10.5 |    184.9      54.0 |    184.9      54.0 |    186.4      54.1
   11.5 |    241.2      58.6 |    241.2      58.6 |    242.6      58.7
   15.0 |    155.5      51.0 |    155.5      51.0 |    153.5      50.8
   18.5 |    272.3      60.7 |    272.3      60.7 |    271.9      60.7
   19.0 |    311.0      63.0 |    311.0      63.0 |    311.3      63.0
   19.5 |    312.8      63.1 |    312.8      63.1 |    313.3      63.1
   20.5 |    234.3      58.1 |    234.3      58.1 |    233.0      58.0
   26.5 |    186.0      54.1 |    186.0      54.1 |    186.0      54.1
   29.5 |    146.8      50.0 |    146.8      50.0 |    145.6      49.9
```

Where both detect voice, Hz values typically agree within 1–3 Hz.
