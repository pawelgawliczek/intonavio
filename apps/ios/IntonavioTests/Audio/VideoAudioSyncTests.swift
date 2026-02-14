@testable import Intonavio
import XCTest

final class VideoAudioSyncTests: XCTestCase {
    func testSyncInitialState() {
        let controller = YouTubePlayerController()
        let engine = AudioEngine()
        let stemPlayer = StemPlayer(engine: engine)
        let sync = VideoAudioSync(
            controller: controller,
            stemPlayer: stemPlayer
        )
        XCTAssertFalse(sync.isActive)
    }

    func testStartStop() {
        let controller = YouTubePlayerController()
        let engine = AudioEngine()
        let stemPlayer = StemPlayer(engine: engine)
        let sync = VideoAudioSync(
            controller: controller,
            stemPlayer: stemPlayer
        )

        sync.start()
        XCTAssertTrue(sync.isActive)

        sync.stop()
        XCTAssertFalse(sync.isActive)
    }

    func testDriftLoggerStats() {
        let logger = DriftLogger.shared
        logger.log(ytTime: 10.0, stemTime: 10.05, drift: 0.05)
        logger.log(ytTime: 20.0, stemTime: 20.1, drift: 0.1)

        let stats = logger.stats
        XCTAssertGreaterThan(stats.count, 0)
    }
}
