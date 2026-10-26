import AppKit

/// Reads what's playing in Apple Music or Spotify and sends play/pause/next/previous.
/// Uses AppleScript, so macOS asks once for permission to control each app.
/// Only apps that are already running are queried, so this never launches anything.
final class MediaService {
    var onUpdate: ((MediaInfo?) -> Void)?

    private let queue = DispatchQueue(label: "topside.media")
    private var timer: Timer?
    private var busy = false

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
        poll()
    }

    func poll() {
        guard !busy else { return }
        busy = true

        let running = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier })
        queue.async { [weak self] in
            guard let self else { return }
            var found: [MediaInfo] = []
            for app in [MediaApp.spotify, MediaApp.music] where running.contains(app.bundleID) {
                if let info = self.query(app) {
                    found.append(info)
                }
            }
            let best = found.first(where: { $0.isPlaying }) ?? found.first
            DispatchQueue.main.async {
                self.busy = false
                self.onUpdate?(best)
            }
        }
    }

    /// `command` is an AppleScript verb: "playpause", "next track" or "previous track".
    func send(_ command: String, to app: MediaApp) {
        queue.async { [weak self] in
            var error: NSDictionary?
            let script = NSAppleScript(source: "tell application \"\(app.scriptName)\" to \(command)")
            _ = script?.executeAndReturnError(&error)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self?.poll()
            }
        }
    }

    // MARK: Internals

    private func query(_ app: MediaApp) -> MediaInfo? {
        let artworkLine = app == .spotify
            ? "set u to artwork url of current track"
            : "set u to \"\""

        let source = """
        tell application "\(app.scriptName)"
            if player state is stopped then return ""
            set s to player state as string
            set t to name of current track
            set a to artist of current track
            \(artworkLine)
            return s & linefeed & t & linefeed & a & linefeed & u
        end tell
        """

        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let result = script.executeAndReturnError(&error)
        if error != nil { return nil }
        guard let text = result.stringValue, !text.isEmpty else { return nil }

        let parts = text.components(separatedBy: "\n")
        guard parts.count >= 3 else { return nil }

        let artworkString = parts.count > 3 ? parts[3] : ""
        return MediaInfo(
            app: app,
            title: parts[1],
            artist: parts[2],
            isPlaying: parts[0].lowercased() == "playing",
            artworkURL: artworkString.isEmpty ? nil : URL(string: artworkString)
        )
    }
}
