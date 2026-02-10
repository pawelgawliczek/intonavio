import SwiftUI
import WebKit

/// UIViewRepresentable wrapping a WKWebView that loads the
/// YouTube IFrame Player API from a local HTTP server.
/// YouTube requires an HTTP/HTTPS origin for embedded playback.
struct YouTubePlayerView: UIViewRepresentable {
    let videoId: String
    let bridge: YouTubeBridge
    let server: YouTubeLocalServer
    let onWebViewReady: (WKWebView) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        config.userContentController.add(
            bridge,
            name: YouTubeBridge.handlerName
        )

        let webView = WKWebView(
            frame: .zero,
            configuration: config
        )
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .black

        context.coordinator.lastVideoId = videoId

        // Initial load is triggered by the ViewModel
        // once the local server is ready.

        DispatchQueue.main.async {
            onWebViewReady(webView)
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if context.coordinator.lastVideoId != videoId {
            context.coordinator.lastVideoId = videoId
            server.updateVideoId(videoId)
            loadPlayer(in: uiView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var lastVideoId: String = ""
    }

    private func loadPlayer(in webView: WKWebView) {
        let url = server.playerURL
        print("[YTPlayer] Loading \(url)")
        webView.load(URLRequest(url: url))
    }
}

/// Provides type-safe JS commands to control the YouTube player.
final class YouTubePlayerController {
    private weak var webView: WKWebView?

    func attach(_ webView: WKWebView) {
        self.webView = webView
    }

    func loadVideo(_ videoId: String) {
        evaluate("player.cueVideoById('\(videoId)')")
    }

    func play() {
        evaluate("player.playVideo()")
    }

    func pause() {
        evaluate("player.pauseVideo()")
    }

    func stop() {
        evaluate("player.stopVideo()")
    }

    func seek(to seconds: Double) {
        evaluate("player.seekTo(\(seconds), true)")
    }

    func setPlaybackRate(_ rate: Double) {
        evaluate("player.setPlaybackRate(\(rate))")
    }

    func mute() {
        evaluate("player.mute()")
    }

    func unmute() {
        evaluate("player.unMute()")
    }

    func startTimePolling(intervalMs: Int = 50) {
        evaluate("startTimePolling(\(intervalMs))")
    }

    func stopTimePolling() {
        evaluate("stopTimePolling()")
    }

    func getCurrentTime(
        completion: @escaping (Double) -> Void
    ) {
        evaluateWithResult("player.getCurrentTime()") { result in
            completion(result as? Double ?? 0)
        }
    }
}

// MARK: - JS Evaluation

private extension YouTubePlayerController {
    func evaluate(_ js: String) {
        webView?.evaluateJavaScript(js) { _, error in
            if let error {
                print("[YT] JS error: \(error.localizedDescription)")
            }
        }
    }

    func evaluateWithResult(
        _ js: String,
        completion: @escaping (Any?) -> Void
    ) {
        webView?.evaluateJavaScript(js) { result, error in
            if let error {
                print("[YT] JS error: \(error.localizedDescription)")
                completion(nil)
            } else {
                completion(result)
            }
        }
    }
}
