import XCTest
@testable import Intonavio

final class ReferencePitchStoreTests: XCTestCase {
    private var store: ReferencePitchStore!

    override func setUp() {
        super.setUp()
        store = ReferencePitchStore()
    }

    // MARK: - Loading

    func testLoadFromData() {
        let data = makeTestData(frameCount: 50)
        store.load(from: data)

        XCTAssertEqual(store.frames.count, 50)
        XCTAssertEqual(store.hopDuration, 0.01)
        XCTAssertFalse(store.isEmpty)
    }

    func testEmptyStoreIsEmpty() {
        XCTAssertTrue(store.isEmpty)
        XCTAssertEqual(store.frames.count, 0)
    }

    func testReset() {
        let data = makeTestData(frameCount: 50)
        store.load(from: data)
        store.reset()
        XCTAssertTrue(store.isEmpty)
    }

    // MARK: - Frame Lookup

    func testFrameAtValidTime() {
        let data = makeTestData(frameCount: 100)
        store.load(from: data)

        let frame = store.frame(at: 0.05) // Should be index 5
        XCTAssertNotNil(frame)
        XCTAssertEqual(frame!.time, 0.05, accuracy: 0.001)
    }

    func testFrameAtZero() {
        let data = makeTestData(frameCount: 10)
        store.load(from: data)

        let frame = store.frame(at: 0)
        XCTAssertNotNil(frame)
        XCTAssertEqual(frame!.time, 0, accuracy: 0.001)
    }

    func testFrameAtNegativeTimeReturnsNil() {
        let data = makeTestData(frameCount: 10)
        store.load(from: data)

        XCTAssertNil(store.frame(at: -1.0))
    }

    func testFrameBeyondEndReturnsNil() {
        let data = makeTestData(frameCount: 10)
        store.load(from: data)

        XCTAssertNil(store.frame(at: 999.0))
    }

    func testFrameOnEmptyStoreReturnsNil() {
        XCTAssertNil(store.frame(at: 0))
    }

    // MARK: - Range Queries

    func testFramesInRange() {
        let data = makeTestData(frameCount: 100)
        store.load(from: data)

        let slice = store.frames(from: 0.1, to: 0.2)
        XCTAssertGreaterThan(slice.count, 0)

        for frame in slice {
            XCTAssertGreaterThanOrEqual(frame.time, 0.1 - 0.01)
            XCTAssertLessThanOrEqual(frame.time, 0.2 + 0.01)
        }
    }

    func testFramesInRangeReturnsEmpty() {
        let data = makeTestData(frameCount: 10)
        store.load(from: data)

        let slice = store.frames(from: 999.0, to: 1000.0)
        XCTAssertTrue(slice.isEmpty)
    }

    func testFramesInRangeOnEmptyStore() {
        let slice = store.frames(from: 0, to: 1.0)
        XCTAssertTrue(slice.isEmpty)
    }

    // MARK: - Total Duration

    func testTotalDuration() {
        let data = makeTestData(frameCount: 100)
        store.load(from: data)

        let expected = 0.01 * 100
        XCTAssertEqual(store.totalDuration, expected, accuracy: 0.001)
    }
}

// MARK: - Helpers

private extension ReferencePitchStoreTests {
    func makeTestData(frameCount: Int) -> ReferencePitchData {
        let hopDuration = 0.01
        let frames = (0..<frameCount).map { i in
            ReferencePitchFrame(
                time: Double(i) * hopDuration,
                frequency: 440.0,
                isVoiced: true,
                midiNote: 69.0,
                rms: nil
            )
        }
        return ReferencePitchData(
            songId: nil,
            sampleRate: 44100,
            hopSize: 256,
            frameCount: frameCount,
            hopDuration: hopDuration,
            frames: frames,
            phrases: []
        )
    }
}
