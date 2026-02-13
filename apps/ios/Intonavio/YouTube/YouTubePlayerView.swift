import SwiftUI
import WebKit

/// UIViewRepresentable wrapping a WKWebView that loads the
/// YouTube IFrame Player API from a local HTTP server.
struct YouTubePlayerView: UIViewRepresentable {
    let videoId: String
    let bridge: YouTubeBridge
    let server: YouTubeLocalServer
    let onWebViewReady: (WKWebView) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.processPool = WebViewPrewarmer.shared.processPool
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
        WebViewPrewarmer.shared.releaseWarmup()
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .black

        context.coordinator.lastVideoId = videoId

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
        AppLogger.player.debug("Loading \(url)")
        webView.load(URLRequest(url: url))
    }
}
