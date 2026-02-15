import WebKit

/// Provides type-safe JS commands to control the YouTube player.
/// Conforms to VideoPlayerProtocol for swappability.
final class YouTubePlayerController: VideoPlayerProtocol {
    private weak var webView: WKWebView?
    private(set) var isReady = false
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0

    func attach(_ webView: WKWebView) {
        self.webView = webView
    }

    func markReady(duration: Double) {
        self.isReady = true
        self.duration = duration
    }

    func updateTime(_ time: Double) {
        self.currentTime = time
    }

    // MARK: - VideoPlayerProtocol

    func play() {
        evaluate("player.playVideo()")
    }

    func pause() {
        evaluate("player.pauseVideo()")
    }

    func seek(to seconds: Double) {
        evaluate("player.seekTo(\(seconds), true)")
    }

    /// Atomic pause + seek to avoid race where seek resumes playback
    /// before the pause takes effect.
    func pauseAndSeek(to seconds: Double) {
        evaluate("player.pauseVideo(); player.seekTo(\(seconds), true)")
    }

    func setPlaybackRate(_ rate: Double) {
        evaluate("player.setPlaybackRate(\(rate))")
    }

    func mute() {
        evaluate("window._ytSavedVolume = player.getVolume(); player.mute(); player.setVolume(0)")
    }

    func unmute() {
        evaluate("player.setVolume(window._ytSavedVolume !== undefined ? window._ytSavedVolume : 100); player.unMute()")
    }

    func startTimePolling(intervalMs: Int = 50) {
        evaluate("startTimePolling(\(intervalMs))")
    }

    func stopTimePolling() {
        evaluate("stopTimePolling()")
    }

    func getCurrentTime(completion: @escaping (Double) -> Void) {
        evaluateWithResult("player.getCurrentTime()") { result in
            completion(result as? Double ?? 0)
        }
    }

    func loadVideo(_ videoId: String) {
        evaluate("player.cueVideoById('\(videoId)')")
    }

    func stop() {
        evaluate("player.stopVideo()")
    }
}

// MARK: - JS Evaluation

private extension YouTubePlayerController {
    func evaluate(_ js: String) {
        webView?.evaluateJavaScript("\(js); void(0)") { _, error in
            if let error {
                AppLogger.player.error("JS error: \(error.localizedDescription)")
            }
        }
    }

    func evaluateWithResult(
        _ js: String,
        completion: @escaping (Any?) -> Void
    ) {
        webView?.evaluateJavaScript(js) { result, error in
            if let error {
                AppLogger.player.error("JS error: \(error.localizedDescription)")
                completion(nil)
            } else {
                completion(result)
            }
        }
    }
}
