@testable import Intonavio
import XCTest

final class StemPlayerTests: XCTestCase {
    func testStemPlayerInitialState() {
        let engine = AudioEngine()
        let player = StemPlayer(engine: engine)
        XCTAssertEqual(player.rate, 1.0)
    }

    func testRateChange() {
        let engine = AudioEngine()
        let player = StemPlayer(engine: engine)
        player.rate = 0.75
        XCTAssertEqual(player.rate, 0.75, accuracy: 0.01)
    }

    func testAudioModeProperties() {
        XCTAssertTrue(AudioMode.original.hasFull)
        XCTAssertFalse(AudioMode.vocalsOnly.hasFull)
        XCTAssertFalse(AudioMode.instrumental.hasFull)

        XCTAssertTrue(AudioMode.vocalsOnly.hasVocals)
        XCTAssertFalse(AudioMode.instrumental.hasVocals)
        XCTAssertFalse(AudioMode.original.hasVocals)

        XCTAssertTrue(AudioMode.instrumental.hasInstrumental)
        XCTAssertFalse(AudioMode.vocalsOnly.hasInstrumental)
        XCTAssertFalse(AudioMode.original.hasInstrumental)
    }
}
