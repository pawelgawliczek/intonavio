@testable import Intonavio
import XCTest

final class YouTubeURLValidatorTests: XCTestCase {
    // MARK: - Valid URLs

    func testStandardWatchURL() {
        XCTAssertTrue(YouTubeURLValidator.isValid("https://www.youtube.com/watch?v=dQw4w9WgXcQ"))
    }

    func testShortURL() {
        XCTAssertTrue(YouTubeURLValidator.isValid("https://youtu.be/dQw4w9WgXcQ"))
    }

    func testEmbedURL() {
        XCTAssertTrue(YouTubeURLValidator.isValid("https://www.youtube.com/embed/dQw4w9WgXcQ"))
    }

    func testShortsURL() {
        XCTAssertTrue(YouTubeURLValidator.isValid("https://www.youtube.com/shorts/dQw4w9WgXcQ"))
    }

    func testMobileURL() {
        XCTAssertTrue(YouTubeURLValidator.isValid("https://m.youtube.com/watch?v=dQw4w9WgXcQ"))
    }

    func testHTTPURL() {
        XCTAssertTrue(YouTubeURLValidator.isValid("http://www.youtube.com/watch?v=dQw4w9WgXcQ"))
    }

    func testURLWithExtraParams() {
        XCTAssertTrue(YouTubeURLValidator.isValid(
            "https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PLx0sYbCqOb8TBPRdmBHs5Iftvv9TPboYG"
        ))
    }

    // MARK: - Invalid URLs

    func testEmptyString() {
        XCTAssertFalse(YouTubeURLValidator.isValid(""))
    }

    func testRandomURL() {
        XCTAssertFalse(YouTubeURLValidator.isValid("https://google.com"))
    }

    func testShortVideoId() {
        XCTAssertFalse(YouTubeURLValidator.isValid("https://youtube.com/watch?v=short"))
    }

    func testNoVideoId() {
        XCTAssertFalse(YouTubeURLValidator.isValid("https://youtube.com/watch"))
    }

    // MARK: - Video ID Extraction

    func testExtractFromWatchURL() {
        let id = YouTubeURLValidator.extractVideoId("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        XCTAssertEqual(id, "dQw4w9WgXcQ")
    }

    func testExtractFromShortURL() {
        let id = YouTubeURLValidator.extractVideoId("https://youtu.be/dQw4w9WgXcQ")
        XCTAssertEqual(id, "dQw4w9WgXcQ")
    }

    func testExtractFromEmbedURL() {
        let id = YouTubeURLValidator.extractVideoId("https://www.youtube.com/embed/dQw4w9WgXcQ")
        XCTAssertEqual(id, "dQw4w9WgXcQ")
    }

    func testExtractReturnsNilForInvalidURL() {
        let id = YouTubeURLValidator.extractVideoId("https://google.com")
        XCTAssertNil(id)
    }
}
