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

---

# Octave Errors & Pitch Quality Roadmap

**Date**: 2026-04-07

## Observed pYIN Failure Modes in Production

After processing 8 songs through the pitch worker, three recurring failure patterns were identified:

### 1. Octave-up errors (2nd harmonic locking)

pYIN's internal HMM penalizes large jumps symmetrically — it does not specifically penalize _octave_ jumps, so it can settle into octave-up state when local autocorrelation favors the 2nd harmonic.

**Example**: Adele "Hello" 1:08–1:13 — 164 frames reported ~932 Hz (Bb5) when the actual vocal was ~466 Hz (Bb4). Surrounding frames before and after were correct, making it a clean sustained octave flip.

### 2. Octave-down errors (sub-harmonic locking)

The mirror failure: pYIN tracks half the actual frequency.

**Example**: Disturbed "Sound of Silence" 2:45 — 56 frames reported ~147 Hz (D3) when the vocal was ~294 Hz (D4). Harder to catch automatically because surrounding context already had wide pitch variation (208–440 Hz), so the median window was unstable.

### 3. Spurious high-frequency detections + missing data in dense sections

In loud orchestral climaxes, the vocal stem has bleed-through from instruments. pYIN either tracks instrument harmonics far above any human vocal range, or fails to lock onto anything at all and reports unvoiced for long stretches despite high RMS energy.

**Example**: Disturbed "Sound of Silence" 3:04–3:10 — 107 frames reported 1500–2000 Hz (MIDI 91–96), well above the highest soprano note (C6 ≈ 1047 Hz), plus large unvoiced gaps where the vocal was clearly present in the mix. The stem separation quality was the root cause.

## Current Mitigation: `fix_octave_errors`

Added to `analyzer.py` as a post-processing step after `build_frames`. Sliding-window median filter, window=51 frames (~0.6s), threshold=10 semitones. Halves frames that deviate >+10 semitones from the local median, doubles frames that deviate <−10 semitones.

**Applied to all 8 existing songs via `scripts/fix_octave_errors_r2.py`** (one-time R2 sweep, idempotent). Frames corrected per song:

| Song                             |                                              Frames Fixed |
| -------------------------------- | --------------------------------------------------------: |
| Feeling Good                     |                                                        37 |
| You've Got A Friend              |                                                        71 |
| Bahaa Sultan - Ebn Adam          |                                                        48 |
| Livin' on Borrowed Time          |                                                        11 |
| Sound Of Silence                 | 17 (+ 56 manual sub-octave + 107 manual artifact removal) |
| Asmahan - Dakhalti Marra         |                                                       166 |
| Sam Smith - Too Good At Goodbyes |                                                        89 |
| Adele - Hello                    |                                                       104 |

**Limitation**: cannot fix errors in sections with high pitch variance (median is unstable) or detections that aren't clean octave multiples of the surrounding melody. Both Sound of Silence problems (sub-octave at 2:45 and bogus high-freq at 3:04) had to be patched manually.

## Researched Improvement Path (April 2026)

Online research (PESTO, RMVPE, BS-Roformer, audio-separator, papers from ISMIR 2023–2025) identified a **complementary stack** where each layer attacks a distinct failure mode:

### Step 1 — Bandpass + lower fmax (1 hr, free win)

Lower `pyin_fmax` from 2093 → **1100 Hz** (highest soprano C6 = 1047 Hz). Add a `scipy.signal.butter` bandpass 65–1100 Hz before pitch extraction. **Mathematically prevents** the Sound of Silence 1500–2000 Hz instrument-harmonic class of errors, since pYIN simply can't see those frequencies anymore.

### Step 2 — Tighten voiced_prob threshold (15 min)

Raise pYIN's voiced probability threshold from default to **0.8**. Reduces low-confidence false positives in noisy stem sections.

### Step 3 — Replace pYIN with PESTO (0.5 day)

**PESTO** (Riou et al., ISMIR 2023 Best Paper, https://github.com/SonyCSLParis/pesto, `pesto-pitch` v2.0.1 Feb 2025, **LGPLv3**) is a self-supervised pitch estimator that matches CREPE accuracy at ~12× real-time on CPU, ~130k params, ~5 ms latency. Returns per-frame confidence in [0,1]. Designed-in resistance to octave errors on monophonic vocals.

License note: LGPLv3 means we run it as a subprocess in the worker (already do this for the BullMQ job), no static linking.

**Why not CREPE?** marl/crepe is effectively abandoned (no releases since ~2021, TF2 dependency). The active fork is **torchcrepe** (PyTorch, MIT) but practitioners on so-vits-svc still report octave failures on singing, so it's not a clean win. PESTO is the maintained, peer-reviewed, fast option.

### Step 4 — RMVPE second opinion (1 day)

**RMVPE** (https://github.com/Dream-High/RMVPE, paper https://arxiv.org/abs/2306.15412 — "Robust Model for Vocal Pitch Estimation in Polyphonic Music") is a deep U-Net + GRU **explicitly designed to extract vocal F0 from polyphonic mixes without needing separation first**. It's the de facto F0 estimator in RVC and so-vits-svc.

Run RMVPE on the **original mix** in parallel with PESTO on the **clean stem**. Reconcile via confidence-weighted median. **Mark frames as unvoiced where they disagree by ≥1 octave** — refusing to guess is better than showing wrong data. This works because the two trackers fail in _uncorrelated_ ways (autocorrelation/HMM vs deep learning, stem-input vs mix-input).

License note: RMVPE upstream license is unclear; vendor weights from an RVC release rather than upstream and verify before shipping.

### Step 5 — Upgrade stem separation to BS-Roformer (2–3 days + GPU)

> **Status update (2026-04-07)**: BS-Roformer (via `audio-separator`) now ships as the **in-house `workers/stem-splitter` worker**, exposed as the `DRAFT` stem source alongside the external StemSplit `STUDIO` source (see `docs/05-audio-pipeline.md`). Users can opt into the cleaner separation per song. This is the "Draft" variant of the dual-source feature; the roadmap notes below still describe the research context.

**Highest ceiling, most invasive.** Replace StemSplit with **BS-Roformer Viperx 1297** (`model_bs_roformer_ep_317_sdr_12.9755.ckpt`) via the `audio-separator` Python package (https://github.com/nomadkaraoke/python-audio-separator, **MIT**, v0.44.1 March 2026, very actively maintained, supports Apple Silicon).

| Model                       | Vocals SDR |
| --------------------------- | ---------: |
| htdemucs_ft (Demucs v4)     |       ~9.5 |
| **BS-Roformer Viperx 1297** |  **12.97** |

That ~3.5 dB improvement roughly halves residual instrument energy in vocal stems. The dense climaxes that currently produce bleed garbage would come out far cleaner.

**Why this is "the bigger project"**:

- Not a code change inside the pitch worker — it replaces the upstream stem-separation step.
- Self-hosted model (BS-Roformer is heavy: ~5–10 min/song on CPU, ~30s on GPU). Either need a GPU on Hostinger or use Runpod/Modal/Replicate for this worker.
- ~150 MB checkpoint to bundle or download at startup.
- Requires re-processing all existing songs and overwriting `stems/{songId}/VOCALS.mp3`.
- Re-trigger pitch analysis for all songs after stems regenerate.

Only commit to this if steps 1–4 leave dense orchestral sections still unusable.

## Recommended Rollout Order

Cheapest first, measure marginal benefit on a regression set after each step.

1. ✅ **DONE (2026-04-07)**: Step 1 — `fmax=1100` + Butterworth bandpass 65–1100 Hz (scipy `butter` order 4 + `sosfiltfilt`) pre-filter in `analyzer.extract_pitch`. All 8 songs re-analyzed against the new pipeline.
2. **This week**: Step 2 — `voiced_prob ≥ 0.8`. Trivial.
3. **This week**: Step 3 — Spike PESTO behind a feature flag, keep pYIN as fallback.
4. **Next**: Step 4 — RMVPE second opinion + reconciliation.
5. **Bigger project, only if needed**: Step 5 — BS-Roformer stem separation.

## Evaluation Metric

Use **R-FFE** (Raw Fundamental Frequency Error, octave-invariant) from the Prompt-Singer paper (https://arxiv.org/abs/2403.11780). Rescales voiced F0 to mean 230 Hz before comparison, so octave errors show up _separately_ from pitch-class errors. This lets you regress against the octave-error fix specifically without conflating it with pitch-class drift.

## Confirmed Skepticism Flags

- **marl/crepe** — abandoned, don't use. Use torchcrepe if you need a CREPE variant.
- **Dream-High/RMVPE** — paper-quality repo, license unclear; vendor weights from an RVC release.
- **torchfcpe** — last release March 2024, author admits it needs cleanup. Fine for real-time, not the top pick for offline accuracy.
- **bs-roformer-infer** — small inference wrapper, fewer eyes on it than `audio-separator`; prefer the latter.

All other packages above (pesto-pitch, audio-separator, parselmouth, librosa) are real, install-ready, and either actively maintained or have massive deployed user bases (RVC/SVC ecosystem).
