import Foundation
import Network

/// Lightweight local HTTP server that serves the YouTube
/// player HTML from localhost. YouTube IFrame API requires
/// an HTTP/HTTPS origin for embedded playback.
final class YouTubeLocalServer: @unchecked Sendable {
    private var listener: NWListener?
    private(set) var port: UInt16 = 0
    private var videoId: String

    var origin: String { "http://localhost:\(port)" }
    var playerURL: URL {
        guard let url = URL(string: "\(origin)/player") else {
            fatalError("Invalid player URL — port: \(port)")
        }
        return url
    }
    var isReady: Bool { port != 0 }

    /// Called on the main queue when the server is ready.
    var onReady: (() -> Void)?

    init(videoId: String) {
        self.videoId = videoId
    }

    func updateVideoId(_ id: String) {
        videoId = id
    }

    func start() {
        let params = NWParameters.tcp
        listener = try? NWListener(using: params, on: .any)

        listener?.stateUpdateHandler = { [weak self] state in
            if case .ready = state,
               let actualPort = self?.listener?.port?.rawValue {
                self?.port = actualPort
                AppLogger.player.info(
                    "Local server listening on port \(actualPort)"
                )
                self?.onReady?()
            }
            if case .failed(let err) = state {
                AppLogger.player.error("Local server failed: \(err)")
            }
        }

        listener?.newConnectionHandler = { [weak self] conn in
            self?.handleConnection(conn)
        }

        listener?.start(queue: .main)
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }
}

// MARK: - Connection Handling

private extension YouTubeLocalServer {
    func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .main)

        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: 65536
        ) { [weak self] data, _, _, _ in
            guard let self, data != nil else {
                connection.cancel()
                return
            }

            let html = YouTubeHTML.template(
                videoId: self.videoId,
                origin: self.origin
            )
            self.sendResponse(html, on: connection)
        }
    }

    func sendResponse(_ html: String, on conn: NWConnection) {
        let body = Data(html.utf8)
        let header = [
            "HTTP/1.1 200 OK",
            "Content-Type: text/html; charset=utf-8",
            "Content-Length: \(body.count)",
            "Connection: close",
            "",
            ""
        ].joined(separator: "\r\n")

        var response = Data(header.utf8)
        response.append(body)

        conn.send(
            content: response,
            completion: .contentProcessed { _ in
                conn.cancel()
            }
        )
    }
}
