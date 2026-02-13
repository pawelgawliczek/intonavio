import WebKit

/// YouTube player event types sent from JS to Swift.
enum YouTubeEvent {
    case ready(duration: Double)
    case stateChange(state: YouTubePlayerState)
    case timeUpdate(time: Double, jsTimestamp: Double)
    case error(code: Int)
    case unknown(raw: [String: Any])
}

/// Maps YouTube IFrame API state constants.
enum YouTubePlayerState: Int {
    case unstarted = -1
    case ended = 0
    case playing = 1
    case paused = 2
    case buffering = 3
    case cued = 5
}

/// WKScriptMessageHandler that parses YouTube player events
/// and forwards them via a callback.
final class YouTubeBridge: NSObject, WKScriptMessageHandler {
    var onEvent: ((YouTubeEvent) -> Void)?

    static let handlerName = "ytEvent"

    func userContentController(
        _ controller: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? [String: Any],
              let event = body["event"] as? String else {
            return
        }

        let parsed = parseEvent(event, body: body)
        DispatchQueue.main.async { [weak self] in
            self?.onEvent?(parsed)
        }
    }
}

// MARK: - Parsing

private extension YouTubeBridge {
    func parseEvent(
        _ event: String,
        body: [String: Any]
    ) -> YouTubeEvent {
        switch event {
        case "ready":
            let duration = body["duration"] as? Double ?? 0
            return .ready(duration: duration)

        case "stateChange":
            let raw = body["state"] as? Int ?? -1
            let state = YouTubePlayerState(rawValue: raw)
                ?? .unstarted
            return .stateChange(state: state)

        case "timeUpdate":
            let time = body["time"] as? Double ?? 0
            let ts = body["ts"] as? Double ?? 0
            return .timeUpdate(time: time, jsTimestamp: ts)

        case "error":
            let code = body["code"] as? Int ?? 0
            return .error(code: code)

        default:
            return .unknown(raw: body)
        }
    }
}
