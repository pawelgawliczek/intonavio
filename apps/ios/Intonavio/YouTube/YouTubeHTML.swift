import Foundation

/// Generates the HTML template for the YouTube IFrame Player API.
enum YouTubeHTML {
    /// Build HTML string with the given video ID and origin.
    static func template(
        videoId: String,
        origin: String = "http://localhost"
    ) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        \(headContent)
        </head>
        <body>
          <div id="player"></div>
          <script src="https://www.youtube.com/iframe_api"></script>
          <script>
          \(playerScript(videoId: videoId, origin: origin))
          \(helperScript)
          </script>
        </body>
        </html>
        """
    }
}

// MARK: - Template Parts

private extension YouTubeHTML {
    static var headContent: String {
        """
        <meta name="viewport" \
        content="width=device-width, initial-scale=1.0, \
        maximum-scale=1.0, user-scalable=no">
        <style>
          * { margin: 0; padding: 0; }
          html, body { width: 100%; height: 100%; \
        background: #000; overflow: hidden; }
          #player { width: 100%; height: 100%; }
        </style>
        """
    }

    static func playerScript(videoId: String, origin: String) -> String {
        """
        var player;
        var pollTimer = null;

        function onYouTubeIframeAPIReady() {
          player = new YT.Player('player', {
            videoId: '\(videoId)',
            playerVars: {
              controls: 0, modestbranding: 1, rel: 0,
              playsinline: 1, fs: 0, disablekb: 1,
              origin: '\(origin)'
            },
            events: {
              onReady: onPlayerReady,
              onStateChange: onPlayerStateChange,
              onError: onPlayerError
            }
          });
        }

        function onPlayerReady(e) {
          postEvent('ready', { duration: player.getDuration() });
        }

        function onPlayerStateChange(e) {
          postEvent('stateChange', { state: e.data });
        }

        function onPlayerError(e) {
          postEvent('error', { code: e.data });
        }
        """
    }

    static var helperScript: String {
        """
        function postEvent(event, data) {
          var msg = Object.assign({ event: event }, data || {});
          window.webkit.messageHandlers.ytEvent.postMessage(msg);
        }

        function startTimePolling(intervalMs) {
          stopTimePolling();
          pollTimer = setInterval(function() {
            if (player && player.getCurrentTime) {
              postEvent('timeUpdate', {
                time: player.getCurrentTime(),
                ts: Date.now()
              });
            }
          }, intervalMs);
        }

        function stopTimePolling() {
          if (pollTimer) {
            clearInterval(pollTimer);
            pollTimer = null;
          }
        }
        """
    }
}
