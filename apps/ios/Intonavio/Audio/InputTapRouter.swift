import AVFoundation

/// Fan-out a single AVAudioEngine input tap to multiple consumers.
/// AVAudioEngine only allows one tap per bus, so this installs a single
/// tap and distributes buffers to all registered consumers.
final class InputTapRouter {
    typealias Consumer = (AVAudioPCMBuffer, AVAudioTime) -> Void

    private let audioEngine: AudioEngine
    private var consumers: [String: Consumer] = [:]
    private let lock = NSLock()

    init(engine: AudioEngine) {
        self.audioEngine = engine
    }

    /// Register a consumer. Installs the input tap when the first consumer is added.
    func addConsumer(
        id: String,
        bufferSize: AVAudioFrameCount,
        format: AVAudioFormat?,
        handler: @escaping Consumer
    ) {
        lock.lock()
        let wasEmpty = consumers.isEmpty
        consumers[id] = handler
        lock.unlock()

        if wasEmpty {
            audioEngine.installInputTap(
                bufferSize: bufferSize,
                format: format
            ) { [weak self] buffer, time in
                self?.distribute(buffer, time: time)
            }
        }
    }

    /// Remove a consumer. Removes the input tap when the last consumer is removed.
    func removeConsumer(id: String) {
        lock.lock()
        consumers.removeValue(forKey: id)
        let isEmpty = consumers.isEmpty
        lock.unlock()

        if isEmpty {
            audioEngine.removeInputTap()
        }
    }

    /// Remove all consumers and the input tap.
    func removeAll() {
        lock.lock()
        consumers.removeAll()
        lock.unlock()
        audioEngine.removeInputTap()
    }

    private func distribute(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        lock.lock()
        let snapshot = consumers
        lock.unlock()

        for (_, handler) in snapshot {
            handler(buffer, time)
        }
    }
}
