# Intonavio

A singing practice app that turns any YouTube song into a pitch trainer. Paste a URL, get the vocals separated from the music, and see your pitch plotted against the original singer in real time.

I built this because I started taking singing lessons and realized that practicing at home without feedback is mostly guesswork. In class, the teacher plays notes and tells you higher or lower. At home, you're on your own. Intonavio gives you that visual feedback loop.

**[Read the blog post](https://pawelgawliczek.cloud/blog/i-built-a-singing-practice-app-because-my-ear-wasnt-ready)** · **[App page](https://pawelgawliczek.cloud/apps/intonavio)**

## Screenshots

<p align="center">
  <img src="screenshots/library.png" alt="Song library" width="230" />
  &nbsp;&nbsp;
  <img src="screenshots/practice.png" alt="Practice mode with pitch detection" width="230" />
  &nbsp;&nbsp;
  <img src="screenshots/scores.png" alt="Phrase-by-phrase scores" width="230" />
</p>

## Features

- **Any YouTube song** - Paste a lyrics video URL. The app extracts audio and prepares it for practice.
- **AI stem separation** - Vocals and instrumental get split automatically using the StemSplit API, so you can karaoke any song or isolate the singer to study their technique.
- **Real-time pitch detection** - Sing into the mic and see your pitch on a piano roll, overlaid on the reference vocalist. Color-coded: green when you're close, red when you're off.
- **Synced lyrics** - The lyrics video plays at the top of the practice screen, scrolling in time with the music.
- **A-B looping** - Set markers on any section, slow it down, repeat until it clicks. Speed goes from 0.25x to 4x.
- **Phrase-by-phrase scoring** - Every phrase gets its own accuracy score so you know exactly which parts need work.
- **Three difficulty levels** - Beginner gives you wide tolerance. Advanced expects you to be almost spot on.
- **Vocal exercises** - Scales, arpeggios, intervals, vibrato. Same pitch detection and scoring as song practice.
- **Karaoke mode** - Play just the instrumental and sing over it. Works with any YouTube song.
- **Best with headphones** - Without them, the mic picks up playback from the speakers, which makes pitch detection less accurate.

## How it works

1. You paste a YouTube URL
2. The API extracts audio and sends it to StemSplit for stem separation
3. A Python worker analyzes the vocal stem with pYIN to build a reference pitch graph
4. The iOS app downloads the stems and pitch data, plays the song, listens to your mic, and scores you in real time

```
iOS App (SwiftUI)  ─┐
macOS App (SwiftUI) ─┼─→ NestJS API ─→ PostgreSQL
Web App (Next.js)   ─┘        │
                              ├─→ Redis (BullMQ)
                              ├─→ Cloudflare R2 (stems + pitch data)
                              └─→ StemSplit API (stem separation)
                                       │
                              Python Worker (pYIN pitch analysis)
```

## Tech stack

| Layer          | Technology                                       |
| -------------- | ------------------------------------------------ |
| iOS/macOS      | SwiftUI, AVAudioEngine, WKWebView                |
| Web            | Next.js 14, React 18, Tailwind CSS, AudioWorklet |
| API            | NestJS, TypeScript, Prisma, BullMQ               |
| Database       | PostgreSQL 16                                    |
| Queue          | Redis 7 (BullMQ)                                 |
| Pitch worker   | Python 3.11, librosa, pYIN                       |
| Storage        | Cloudflare R2                                    |
| Auth           | Apple Sign In, Google OAuth, Email/Password, JWT |
| Infrastructure | Docker Compose, Caddy, GitHub Actions            |
| Monorepo       | Turborepo, pnpm workspaces                       |

## Project structure

```
intonavio/
├── apps/
│   ├── api/                  # NestJS backend
│   ├── web/                  # Next.js web client
│   └── ios/                  # SwiftUI iOS/macOS app
├── packages/
│   └── shared/               # Shared TypeScript types
├── workers/
│   └── pitch-analyzer/       # Python pitch analysis worker
├── docs/                     # Architecture & design docs
├── screenshots/              # App screenshots
├── docker-compose.dev.yml    # Local dev (PostgreSQL + Redis)
└── docker-compose.prod.yml   # Production (all services)
```

## Getting started

### Prerequisites

- Node.js 20+
- pnpm 10+
- Docker and Docker Compose
- Python 3.11+ (for the pitch worker)
- Xcode 15+ (for iOS development)

### Setup

```bash
git clone https://github.com/pawelgawliczek/intonavio.git
cd intonavio

# Install dependencies
pnpm install

# Copy environment variables
cp .env.example .env
# Edit .env with your credentials (R2, StemSplit API key, etc.)

# Start PostgreSQL and Redis
docker compose -f docker-compose.dev.yml up -d

# Push database schema and generate Prisma client
pnpm db:push
pnpm db:generate

# Start the API and web app
pnpm dev
```

### Python worker

```bash
cd workers/pitch-analyzer
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python -m src.worker
```

### iOS app

```bash
cd apps/ios
xcodegen generate
open Intonavio.xcodeproj
```

### Running tests

```bash
# TypeScript (API + Web)
pnpm test

# Python worker
cd workers/pitch-analyzer
pytest

# iOS
xcodebuild -project apps/ios/Intonavio.xcodeproj -scheme Intonavio \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

## External services

| Service                           | Purpose                                 | Required         |
| --------------------------------- | --------------------------------------- | ---------------- |
| [StemSplit](https://stemsplit.io) | Audio stem separation                   | Yes              |
| Cloudflare R2                     | Object storage for stems and pitch data | Yes              |
| Apple Developer Account           | Apple Sign In                           | For iOS auth     |
| Google Cloud Console              | Google OAuth                            | For web/iOS auth |

## Documentation

The entire app was designed in documentation before writing any code. Docs are in [`docs/`](docs/):

- [Product overview](docs/01-overview.md)
- [System architecture](docs/02-architecture.md)
- [API design](docs/03-api-design.md)
- [Data models](docs/04-data-models.md)
- [Audio pipeline](docs/05-audio-pipeline.md)
- [Real-time pitch detection](docs/06-realtime-pitch.md)
- [YouTube looping](docs/07-youtube-looping.md)
- [Infrastructure](docs/08-infrastructure.md)
- [Code quality standards](docs/12-code-quality.md)
- [Testing strategy](docs/14-testing-strategy.md)

## License

[MIT](LICENSE)
