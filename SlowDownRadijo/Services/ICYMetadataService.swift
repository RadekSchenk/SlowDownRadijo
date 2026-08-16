import Foundation

/// Periodically reads the live ICY (Shoutcast/Icecast) `StreamTitle`
/// metadata embedded in the audio stream itself.
///
/// Verified manually with:
/// ```
/// curl -H "Icy-MetaData: 1" -D - https://icecast5.play.cz/slowdown.aac
/// ```
/// which returns an `icy-metaint: 16000` response header followed by an
/// in-band `StreamTitle='ARTIST - TITLE';` block every 16000 audio bytes.
///
/// We parse this ourselves via a short-lived `URLSessionDataTask` rather
/// than relying on `AVPlayerItemMetadataOutput`, because AVPlayer's built-in
/// ICY parsing for plain MP3/AAC Icecast mounts (as opposed to HLS timed
/// metadata) is undocumented and inconsistent across iOS versions. This
/// approach is independent of AVPlayer and of slowdownradijo.cz's own
/// WordPress site — it only talks to the Icecast server directly.
final class ICYMetadataService: NSObject, ObservableObject {
    @Published private(set) var currentTrack: NowPlayingTrack?

    private let streamURL: URL
    private let pollInterval: TimeInterval
    private var timer: Timer?
    private var session: URLSession!
    private var activeTask: URLSessionDataTask?

    private var metaInt: Int?
    private var buffer = Data()
    private var bytesUntilMeta = 0
    private var expectingMetaLength = false
    private var metaLength = 0

    init(streamURL: URL = RadioPlayerService.streamURL, pollInterval: TimeInterval = 20) {
        self.streamURL = streamURL
        self.pollInterval = pollInterval
        super.init()
        session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
    }

    func start() {
        pollOnce()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.pollOnce()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        activeTask?.cancel()
        activeTask = nil
    }

    private func pollOnce() {
        guard activeTask == nil else { return }
        resetParseState()

        var request = URLRequest(url: streamURL)
        request.setValue("1", forHTTPHeaderField: "Icy-MetaData")
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let task = session.dataTask(with: request)
        activeTask = task
        task.resume()
    }

    private func resetParseState() {
        metaInt = nil
        buffer.removeAll()
        bytesUntilMeta = 0
        expectingMetaLength = false
        metaLength = 0
    }

    private func finish(task: URLSessionDataTask) {
        task.cancel()
        if activeTask === task {
            activeTask = nil
        }
        buffer.removeAll()
    }
}

extension ICYMetadataService: URLSessionDataDelegate {
    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let http = response as? HTTPURLResponse,
              let metaIntString = http.value(forHTTPHeaderField: "icy-metaint"),
              let metaIntValue = Int(metaIntString), metaIntValue > 0 else {
            completionHandler(.cancel)
            return
        }
        metaInt = metaIntValue
        bytesUntilMeta = metaIntValue
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard metaInt != nil else { return }
        buffer.append(data)
        parseBuffer(task: dataTask)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if activeTask === task {
            activeTask = nil
        }
    }

    /// Walks the buffered bytes: skip `bytesUntilMeta` audio bytes, read the
    /// one-byte metadata length, then (if non-zero) read that many bytes as
    /// the `StreamTitle='...'` block. We stop at the first length byte we
    /// see — enough for one title read — to keep each poll a short,
    /// bounded round trip instead of streaming audio indefinitely.
    private func parseBuffer(task: URLSessionDataTask) {
        var consumed = 0

        while consumed < buffer.count {
            if expectingMetaLength {
                let available = buffer.count - consumed
                guard available >= metaLength else { break }
                let start = buffer.startIndex + consumed
                let metaData = buffer.subdata(in: start..<(start + metaLength))
                handleMetadataBlock(metaData)
                finish(task: task)
                return
            } else if bytesUntilMeta > 0 {
                let available = buffer.count - consumed
                let skip = min(bytesUntilMeta, available)
                bytesUntilMeta -= skip
                consumed += skip
            } else {
                let lengthByte = buffer[buffer.startIndex + consumed]
                consumed += 1
                metaLength = Int(lengthByte) * 16
                if metaLength == 0 {
                    // Server reported "no metadata change" this cycle.
                    finish(task: task)
                    return
                }
                expectingMetaLength = true
            }
        }

        if consumed > 0 {
            buffer.removeSubrange(buffer.startIndex..<(buffer.startIndex + consumed))
        }
    }

    private func handleMetadataBlock(_ data: Data) {
        guard let raw = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1) else { return }
        guard let titleStart = raw.range(of: "StreamTitle='") else { return }
        let rest = raw[titleStart.upperBound...]
        guard let titleEnd = rest.range(of: "';") else { return }
        let title = String(rest[..<titleEnd.lowerBound])

        guard let track = NowPlayingTrack.parse(streamTitle: title) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.currentTrack = track
        }
    }
}
