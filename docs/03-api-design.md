# Intonavio — API Design

## Base URL

```
https://api.intonavio.com/v1
```

All endpoints require `Authorization: Bearer <jwt>` unless noted otherwise.

---

## Authentication Flows

### Apple Sign In (iOS / macOS / Web)

```mermaid
sequenceDiagram
    participant User as Singer
    participant App as Client
    participant Apple as Apple Sign In
    participant API as NestJS API
    participant DB as PostgreSQL

    User->>App: Tap "Sign in with Apple"
    App->>Apple: ASAuthorizationAppleIDRequest
    Apple-->>App: identityToken + authorizationCode
    App->>API: POST /auth/apple { identityToken, authorizationCode }
    API->>Apple: Verify identityToken (JWKS)
    Apple-->>API: Valid (sub, email)
    API->>DB: Find or create User + AuthProvider
    DB-->>API: User record
    API-->>App: { accessToken, refreshToken, user }
    App->>App: Store tokens in Keychain / localStorage
```

### Google OAuth (Web / iOS)

```mermaid
sequenceDiagram
    participant User as Singer
    participant App as Client
    participant Google as Google OAuth
    participant API as NestJS API
    participant DB as PostgreSQL

    User->>App: Tap "Sign in with Google"
    App->>Google: OAuth consent screen
    Google-->>App: authorization code
    App->>API: POST /auth/google { code, redirectUri }
    API->>Google: Exchange code for tokens
    Google-->>API: id_token + access_token
    API->>API: Verify id_token (Google JWKS)
    API->>DB: Find or create User + AuthProvider
    DB-->>API: User record
    API-->>App: { accessToken, refreshToken, user }
```

### Email / Password (Web)

```mermaid
sequenceDiagram
    participant User as Singer
    participant App as Web App
    participant API as NestJS API
    participant DB as PostgreSQL

    Note over User,DB: Registration
    User->>App: Enter email + password
    App->>API: POST /auth/register { email, password, displayName }
    API->>API: Hash password (bcrypt)
    API->>DB: Create User + AuthProvider (EMAIL)
    API-->>App: { accessToken, refreshToken, user }

    Note over User,DB: Login
    User->>App: Enter email + password
    App->>API: POST /auth/login { email, password }
    API->>DB: Find AuthProvider (EMAIL, email)
    API->>API: Verify password (bcrypt)
    API-->>App: { accessToken, refreshToken, user }
```

## Song Processing Flow

```mermaid
sequenceDiagram
    participant Client as App
    participant API as NestJS API
    participant DB as PostgreSQL
    participant Queue as BullMQ
    participant SS as StemSplit API
    participant R2 as Cloudflare R2
    participant Worker as Python Worker

    Client->>API: POST /songs { youtubeUrl }
    API->>DB: Check if song exists (by videoId)
    alt Song already processed
        DB-->>API: Existing song with stems
        API-->>Client: 200 { song, stems }
    else New song
        API->>DB: Create song (status: QUEUED)
        API->>Queue: Enqueue stem-split job
        API-->>Client: 202 { song (status: QUEUED) }
    end

    Queue->>SS: POST /api/v1/youtube-jobs { youtube_url, split_type }
    SS-->>Queue: { job_id }
    Queue->>DB: Update song (status: SPLITTING, externalJobId)

    Note over SS: Processing (1-5 min)

    SS->>API: POST /webhooks/stemsplit { job_id, status, stems[] }
    API->>SS: GET stem download URLs
    API->>R2: Upload stems (vocals.mp3, instrumental.mp3, ...)
    API->>DB: Create Stem records, update song (status: ANALYZING)
    API->>Queue: Enqueue pitch-analysis job

    Queue->>Worker: Analyze vocal stem pitch
    Worker->>R2: Download vocal stem
    Worker->>Worker: pYIN pitch extraction
    Worker->>R2: Upload pitch data JSON
    Worker->>DB: Create PitchData record
    Worker->>DB: Update song (status: READY)
```

## Practice Session Flow

```mermaid
sequenceDiagram
    participant Singer
    participant App as iOS App
    participant YT as YouTube Player
    participant R2 as Cloudflare R2
    participant API as NestJS API

    Singer->>App: Select song to practice
    App->>R2: Fetch stems (instrumental.mp3, vocals.mp3)
    App->>R2: Fetch pitch data (reference.json)
    App->>YT: Load YouTube video (for lyrics display)

    Singer->>App: Tap Play
    App->>YT: Play video (muted or synced)
    App->>App: Play selected stems via AVAudioEngine
    App->>App: Start microphone capture

    loop Every ~23ms (1024 samples @ 44.1kHz)
        App->>App: YIN pitch detection on mic buffer
        App->>App: Look up reference pitch at current time
        App->>App: Compute cents deviation
        App->>App: Update piano roll UI
    end

    Singer->>App: Stop / End session
    App->>API: POST /sessions { songId, duration, pitchLog[], score }
    API-->>App: 201 { session }
```

---

## Endpoint Reference

### Auth

| Method   | Path             | Description                           | Auth          |
| -------- | ---------------- | ------------------------------------- | ------------- |
| `POST`   | `/auth/apple`    | Exchange Apple identity token for JWT | No            |
| `POST`   | `/auth/google`   | Exchange Google OAuth code for JWT    | No            |
| `POST`   | `/auth/register` | Register with email and password      | No            |
| `POST`   | `/auth/login`    | Login with email and password         | No            |
| `POST`   | `/auth/refresh`  | Refresh access token                  | Refresh token |
| `DELETE` | `/auth/account`  | Delete account and all data           | Yes           |

#### `POST /auth/apple`

**Request:**

```json
{
  "identityToken": "eyJ...",
  "authorizationCode": "c2a...",
  "fullName": { "givenName": "Jane", "familyName": "Doe" }
}
```

**Response (200):**

```json
{
  "accessToken": "eyJ...",
  "refreshToken": "rt_...",
  "user": {
    "id": "usr_abc123",
    "email": "jane@icloud.com",
    "displayName": "Jane D."
  }
}
```

#### `POST /auth/google`

**Request:**

```json
{
  "code": "4/0AX4XfWh...",
  "redirectUri": "https://app.intonavio.com/auth/google/callback"
}
```

**Response (200):** Same shape as Apple auth response.

#### `POST /auth/register`

**Request:**

```json
{
  "email": "jane@example.com",
  "password": "securePassword123",
  "displayName": "Jane D."
}
```

**Response (201):** Same shape as Apple auth response.

#### `POST /auth/login`

**Request:**

```json
{
  "email": "jane@example.com",
  "password": "securePassword123"
}
```

**Response (200):** Same shape as Apple auth response.

---

### Songs

| Method   | Path         | Description                            |
| -------- | ------------ | -------------------------------------- |
| `POST`   | `/songs`     | Submit a YouTube URL for processing    |
| `GET`    | `/songs/:id` | Get song details with stems and status |
| `GET`    | `/songs`     | List user's songs (paginated)          |
| `DELETE` | `/songs/:id` | Remove song from user's library        |

#### `POST /songs`

**Request:**

```json
{
  "youtubeUrl": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
}
```

**Response (202):**

```json
{
  "id": "song_xyz789",
  "videoId": "dQw4w9WgXcQ",
  "title": "Rick Astley - Never Gonna Give You Up",
  "thumbnailUrl": "https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg",
  "duration": 213,
  "status": "QUEUED",
  "stems": [],
  "createdAt": "2025-06-01T12:00:00Z"
}
```

#### `GET /songs/:id`

**Response (200) — when READY:**

```json
{
  "id": "song_xyz789",
  "videoId": "dQw4w9WgXcQ",
  "title": "Rick Astley - Never Gonna Give You Up",
  "duration": 213,
  "status": "READY",
  "stems": [
    {
      "id": "stem_1",
      "type": "VOCALS",
      "url": "https://r2.intonavio.com/stems/song_xyz789/vocals.mp3",
      "format": "mp3"
    },
    {
      "id": "stem_2",
      "type": "INSTRUMENTAL",
      "url": "https://r2.intonavio.com/stems/song_xyz789/instrumental.mp3",
      "format": "mp3"
    },
    {
      "id": "stem_3",
      "type": "DRUMS",
      "url": "https://r2.intonavio.com/stems/song_xyz789/drums.mp3",
      "format": "mp3"
    },
    {
      "id": "stem_4",
      "type": "BASS",
      "url": "https://r2.intonavio.com/stems/song_xyz789/bass.mp3",
      "format": "mp3"
    },
    {
      "id": "stem_5",
      "type": "OTHER",
      "url": "https://r2.intonavio.com/stems/song_xyz789/other.mp3",
      "format": "mp3"
    }
  ],
  "pitchData": {
    "id": "pitch_1",
    "url": "https://r2.intonavio.com/pitch/song_xyz789/reference.json"
  },
  "createdAt": "2025-06-01T12:00:00Z"
}
```

---

### Stems

| Method | Path                               | Description                |
| ------ | ---------------------------------- | -------------------------- |
| `GET`  | `/songs/:songId/stems`             | List stems for a song      |
| `GET`  | `/songs/:songId/stems/:stemId/url` | Get presigned download URL |

---

### Sessions

| Method | Path            | Description                        |
| ------ | --------------- | ---------------------------------- |
| `POST` | `/sessions`     | Save a practice session            |
| `GET`  | `/sessions`     | List past sessions (paginated)     |
| `GET`  | `/sessions/:id` | Get session details with pitch log |

#### `POST /sessions`

**Request:**

```json
{
  "songId": "song_xyz789",
  "duration": 45,
  "loopStart": 30.5,
  "loopEnd": 55.2,
  "speed": 0.75,
  "overallScore": 72.5,
  "pitchLog": [
    { "time": 30.5, "detectedHz": 440.0, "referenceHz": 440.0, "cents": 0 },
    { "time": 30.55, "detectedHz": 442.1, "referenceHz": 440.0, "cents": 8.3 }
  ]
}
```

**Response (201):**

```json
{
  "id": "sess_abc",
  "songId": "song_xyz789",
  "duration": 45,
  "overallScore": 72.5,
  "createdAt": "2025-06-01T12:30:00Z"
}
```

---

### Webhooks (Internal)

| Method | Path                  | Description                       | Auth           |
| ------ | --------------------- | --------------------------------- | -------------- |
| `POST` | `/webhooks/stemsplit` | StemSplit job completion callback | Webhook secret |

---

## Error Responses

All errors follow a consistent format:

```json
{
  "statusCode": 404,
  "error": "Not Found",
  "message": "Song not found"
}
```

| Status | Usage                                                |
| ------ | ---------------------------------------------------- |
| `400`  | Invalid request body or parameters                   |
| `401`  | Missing or invalid JWT                               |
| `403`  | Accessing another user's resource                    |
| `404`  | Resource not found                                   |
| `409`  | Song already being processed (duplicate YouTube URL) |
| `429`  | Rate limit exceeded                                  |
| `500`  | Internal server error                                |
