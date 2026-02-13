import Foundation

/// Protocol for swappable video player implementations.
protocol VideoPlayerProtocol: AnyObject {
    var isReady: Bool { get }
    var currentTime: Double { get }
    var duration: Double { get }

    func play()
    func pause()
    func seek(to seconds: Double)
    func setPlaybackRate(_ rate: Double)
    func mute()
    func unmute()
    func startTimePolling(intervalMs: Int)
    func stopTimePolling()
    func getCurrentTime(completion: @escaping (Double) -> Void)
}
