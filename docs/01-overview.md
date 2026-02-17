# Intonavio — Product Overview

## Vision

Intonavio is a singing practice app that transforms YouTube lyrics videos into interactive training sessions. By combining stem separation, real-time pitch detection, and looping controls, singers can isolate vocals, practice difficult passages at reduced speed, and get visual feedback on their pitch accuracy — all using the vast library of lyrics videos already on YouTube.

## Problem Statement

Singers who practice with YouTube lyrics videos lack tools to:

- **Isolate or remove vocals** from the backing track
- **Loop specific sections** (verse, chorus, bridge) without manual rewinding
- **See their pitch** compared to the reference vocal in real time
- **Track progress** across practice sessions

Existing karaoke apps use limited licensed catalogs. Intonavio leverages YouTube's unlimited library and adds the missing practice tools.

## Target Users

- Amateur and semi-professional singers practicing at home
- Vocal students preparing for lessons or auditions
- Choir members learning their part
- Hobbyist singers who want structured practice with their favorite songs

## Core Features

| Feature                        | Description                                                                                                                                       |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| **YouTube Integration**        | Paste any YouTube lyrics video URL to start practicing                                                                                            |
| **Stem Separation**            | Split audio into vocals + instrumental via StemSplit API (YouTube flow). File upload flow supports up to 6 stems.                                 |
| **A-B Looping**                | Set loop markers on the video timeline, repeat sections at adjustable speed (0.25x–4x)                                                            |
| **Real-Time Pitch Detection**  | Detect the singer's pitch via microphone and display on an interactive piano roll (touch to pause, swipe to scrub, long-press to loop a phrase)   |
| **Pitch Comparison**           | Overlay detected pitch against the reference vocal pitch, color-coded by accuracy                                                                 |
| **Scoring**                    | Per-note and per-session accuracy scores with historical tracking, 3 difficulty levels (Beginner/Intermediate/Advanced) with separate best scores |
| **Practice Sessions**          | Save and review past sessions with timestamped pitch data                                                                                         |
| **Audio Mode Toggle**          | Switch between original audio, instrumental only, or vocals only during practice                                                                  |
| **Exercises**                  | Pre-built vocal exercises (scales, arpeggios, intervals, vibrato, breathing) with community sharing                                               |
| **Toggleable Practice Layout** | Switch between lyrics-focused (video 65%, pitch 35%) and pitch-focused (video 25%, pitch 75%) modes                                               |

## Platform Strategy

| Phase | Platform  | Technology                | Notes                                                  |
| ----- | --------- | ------------------------- | ------------------------------------------------------ |
| 1     | **iOS**   | SwiftUI + AVAudioEngine   | Primary target — real-time pitch via native audio APIs |
| 2     | **macOS** | SwiftUI (shared codebase) | Catalyst or native macOS target from the iOS project   |
| 3     | **Web**   | Next.js + AudioWorklet    | SaaS model, broader reach, subscription billing        |

**Authentication**: Apple Sign In (iOS/macOS/Web), Google OAuth (Web/iOS), Email/Password (Web). Users can link multiple auth providers to one account.

iOS is first because:

- AVAudioEngine provides low-latency microphone access ideal for pitch detection
- WKWebView can embed YouTube videos with JavaScript bridge for looping control
- The App Store is a natural distribution channel for practice tools
- SwiftUI code shares well with a future macOS target

## What Intonavio Is Not

- Not a karaoke app with a licensed song catalog
- Not a music production tool (no editing, mixing, or export)
- Not a vocal lesson platform (no instructional content)
- Not a social/sharing platform (exercise sharing is limited to community browse, not a social feed)

Intonavio is a **practice tool** — focused, personal, and built around the singer's workflow of picking a song, isolating parts, looping sections, and improving pitch accuracy over time.
