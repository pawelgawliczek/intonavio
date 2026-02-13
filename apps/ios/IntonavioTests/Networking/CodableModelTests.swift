// swiftlint:disable force_unwrapping non_optional_string_data_conversion
@testable import Intonavio
import XCTest

final class CodableModelTests: XCTestCase {
    private let decoder = JSONDecoder()

    // MARK: - Auth Models

    func testDecodeAuthResponse() throws {
        let json = """
        {
            "accessToken": "eyJ...",
            "refreshToken": "rt_...",
            "user": {
                "id": "user1",
                "email": "jane@example.com",
                "displayName": "Jane D."
            }
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(AuthResponse.self, from: json)
        XCTAssertEqual(response.accessToken, "eyJ...")
        XCTAssertEqual(response.refreshToken, "rt_...")
        XCTAssertEqual(response.user.id, "user1")
        XCTAssertEqual(response.user.email, "jane@example.com")
        XCTAssertEqual(response.user.displayName, "Jane D.")
    }

    func testDecodeAuthResponseNullEmail() throws {
        let json = """
        {
            "accessToken": "token",
            "refreshToken": "refresh",
            "user": { "id": "u1", "email": null, "displayName": "Apple User" }
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(AuthResponse.self, from: json)
        XCTAssertNil(response.user.email)
    }

    // MARK: - Song Models

    func testDecodeSongResponseReady() throws {
        let json = """
        {
            "id": "song1",
            "videoId": "dQw4w9WgXcQ",
            "title": "Rick Astley - Never Gonna Give You Up",
            "thumbnailUrl": "https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg",
            "duration": 213,
            "status": "READY",
            "stems": [
                { "id": "s1", "type": "VOCALS", "storageKey": "stems/song1/vocals.mp3", "format": "mp3" },
                { "id": "s2", "type": "DRUMS", "storageKey": "stems/song1/drums.mp3", "format": "mp3" }
            ],
            "pitchData": { "id": "p1", "storageKey": "pitch/song1/reference.json" },
            "createdAt": "2025-06-01T12:00:00Z"
        }
        """.data(using: .utf8)!

        let song = try decoder.decode(SongResponse.self, from: json)
        XCTAssertEqual(song.id, "song1")
        XCTAssertEqual(song.status, .ready)
        XCTAssertEqual(song.stems.count, 2)
        XCTAssertEqual(song.stems[0].type, .vocals)
        XCTAssertNotNil(song.pitchData)
    }

    func testDecodeSongResponseQueued() throws {
        let json = """
        {
            "id": "song2",
            "videoId": "abc123",
            "title": "abc123",
            "thumbnailUrl": "https://img.youtube.com/vi/abc123/maxresdefault.jpg",
            "duration": 0,
            "status": "QUEUED",
            "stems": [],
            "pitchData": null,
            "createdAt": "2025-06-01T12:00:00Z"
        }
        """.data(using: .utf8)!

        let song = try decoder.decode(SongResponse.self, from: json)
        XCTAssertEqual(song.status, .queued)
        XCTAssertTrue(song.stems.isEmpty)
        XCTAssertNil(song.pitchData)
    }

    func testSongStatusIsProcessing() {
        XCTAssertTrue(SongStatus.queued.isProcessing)
        XCTAssertTrue(SongStatus.splitting.isProcessing)
        XCTAssertTrue(SongStatus.analyzing.isProcessing)
        XCTAssertFalse(SongStatus.ready.isProcessing)
        XCTAssertFalse(SongStatus.failed.isProcessing)
    }

    // MARK: - Session Models

    func testDecodeSessionResponse() throws {
        let json = """
        {
            "id": "sess1",
            "songId": "song1",
            "duration": 45,
            "loopStart": 30.5,
            "loopEnd": 55.2,
            "speed": 0.75,
            "overallScore": 72.5,
            "createdAt": "2025-06-01T12:30:00Z"
        }
        """.data(using: .utf8)!

        let session = try decoder.decode(SessionResponse.self, from: json)
        XCTAssertEqual(session.id, "sess1")
        XCTAssertEqual(session.duration, 45)
        XCTAssertEqual(session.loopStart, 30.5)
        XCTAssertEqual(session.speed, 0.75)
    }

    func testDecodeSessionDetailWithPitchLog() throws {
        let json = """
        {
            "id": "sess1",
            "songId": "song1",
            "duration": 45,
            "loopStart": null,
            "loopEnd": null,
            "speed": 1.0,
            "overallScore": 85.0,
            "pitchLog": [
                { "time": 30.5, "detectedHz": 440.0, "referenceHz": 440.0, "cents": 0.0 },
                { "time": 30.55, "detectedHz": 442.1, "referenceHz": 440.0, "cents": 8.3 }
            ],
            "createdAt": "2025-06-01T12:30:00Z"
        }
        """.data(using: .utf8)!

        let detail = try decoder.decode(SessionDetailResponse.self, from: json)
        XCTAssertEqual(detail.pitchLog.count, 2)
        XCTAssertEqual(detail.pitchLog[0].detectedHz, 440.0)
        XCTAssertNil(detail.loopStart)
    }

    // MARK: - Paginated Response

    func testDecodePaginatedSongs() throws {
        let json = """
        {
            "data": [
                {
                    "id": "s1", "videoId": "v1", "title": "Song 1",
                    "thumbnailUrl": "https://example.com/thumb.jpg",
                    "duration": 180, "status": "READY", "stems": [],
                    "pitchData": null, "createdAt": "2025-06-01T12:00:00Z"
                }
            ],
            "meta": { "page": 1, "limit": 20, "total": 1, "totalPages": 1 }
        }
        """.data(using: .utf8)!

        let result = try decoder.decode(PaginatedResponse<SongResponse>.self, from: json)
        XCTAssertEqual(result.data.count, 1)
        XCTAssertEqual(result.meta.total, 1)
        XCTAssertEqual(result.meta.totalPages, 1)
    }

    // MARK: - Presigned URL

    func testDecodePresignedURL() throws {
        let json = """
        { "url": "https://r2.example.com/stem.mp3?token=abc", "expiresIn": 900 }
        """.data(using: .utf8)!

        let result = try decoder.decode(PresignedURLResponse.self, from: json)
        XCTAssertTrue(result.url.contains("r2.example.com"))
        XCTAssertEqual(result.expiresIn, 900)
    }

    // MARK: - Error Model

    func testDecodeAPIError() throws {
        let json = """
        {
            "statusCode": 404,
            "error": "Not Found",
            "message": "Song not found in your library",
            "traceId": "trc_abc123"
        }
        """.data(using: .utf8)!

        let error = try decoder.decode(APIError.self, from: json)
        XCTAssertEqual(error.statusCode, 404)
        XCTAssertEqual(error.message, "Song not found in your library")
        XCTAssertEqual(error.traceId, "trc_abc123")
    }
}
