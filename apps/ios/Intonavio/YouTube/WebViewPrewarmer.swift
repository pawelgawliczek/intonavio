import WebKit

/// Pre-warms WKWebView processes at app launch so the practice view
/// loads faster instead of waiting for WebContent/GPU/Network process
/// cold start.
///
/// Usage: Call `WebViewPrewarmer.shared.warmUp()` early (e.g., in onAppear
/// of the root view). The YouTubePlayerView uses the shared process pool.
@MainActor
final class WebViewPrewarmer {
    nonisolated(unsafe) static let shared = WebViewPrewarmer()

    let processPool = WKProcessPool()
    private var warmupWebView: WKWebView?

    private init() {}

    /// Spins up WebKit sub-processes by loading a lightweight page
    /// in a hidden WKWebView sharing the same process pool.
    /// The page includes a minimal canvas to prevent GPU IdleExit.
    func warmUp() {
        guard warmupWebView == nil else { return }

        let config = WKWebViewConfiguration()
        config.processPool = processPool
        #if os(iOS)
        config.allowsInlineMediaPlayback = true
        #endif
        config.mediaTypesRequiringUserActionForPlayback = []

        let wv = WKWebView(
            frame: .init(x: 0, y: 0, width: 1, height: 1),
            configuration: config
        )
        wv.loadHTMLString(keepAliveHTML, baseURL: nil)
        warmupWebView = wv

        AppLogger.player.info("WKWebView pre-warm started")
    }

    /// Release the warm-up web view once the real player is loaded.
    func releaseWarmup() {
        warmupWebView = nil
    }

    /// Minimal HTML that keeps WebContent + GPU processes alive.
    private var keepAliveHTML: String {
        """
        <html><body style="margin:0;background:#000">
        <canvas id="c" width="1" height="1"></canvas>
        <script>
        var x=document.getElementById('c').getContext('2d');
        setInterval(function(){x.fillRect(0,0,1,1);},3000);
        </script></body></html>
        """
    }
}
