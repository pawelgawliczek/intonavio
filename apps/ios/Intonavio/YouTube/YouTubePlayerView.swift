import SwiftUI
import WebKit

// MARK: - iOS

#if os(iOS)
/// UIViewRepresentable wrapping a WKWebView that loads the
/// YouTube IFrame Player API from a local HTTP server.
struct YouTubePlayerView: UIViewRepresentable {
    let videoId: String
    let bridge: YouTubeBridge
    let server: YouTubeLocalServer
    let onWebViewReady: (WKWebView) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let webView = createWebView(context: context)
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        updateWebView(uiView, context: context)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
}
#endif

// MARK: - macOS

#if os(macOS)
/// NSViewRepresentable wrapping a WKWebView that loads the
/// YouTube IFrame Player API from a local HTTP server.
struct YouTubePlayerView: NSViewRepresentable {
    let videoId: String
    let bridge: YouTubeBridge
    let server: YouTubeLocalServer
    let onWebViewReady: (WKWebView) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let webView = createWebView(context: context)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        updateWebView(nsView, context: context)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
}
#endif

// MARK: - Shared Logic

extension YouTubePlayerView {
    final class Coordinator {
        var lastVideoId: String = ""
    }

    func createWebView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.processPool = WebViewPrewarmer.shared.processPool
        #if os(iOS)
        config.allowsInlineMediaPlayback = true
        #endif
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

        context.coordinator.lastVideoId = videoId

        DispatchQueue.main.async {
            onWebViewReady(webView)
        }

        return webView
    }

    func updateWebView(_ webView: WKWebView, context: Context) {
        if context.coordinator.lastVideoId != videoId {
            context.coordinator.lastVideoId = videoId
            server.updateVideoId(videoId)
            loadPlayer(in: webView)
        }
    }

    private func loadPlayer(in webView: WKWebView) {
        let url = server.playerURL
        AppLogger.player.debug("Loading \(url)")
        webView.load(URLRequest(url: url))
    }
}
