import AppKit
import Combine
import SwiftUI

/// Everything the island shows, plus the actions its buttons and sliders trigger.
final class IslandModel: ObservableObject {
    @Published var isExpanded = false
    @Published var volume: Float = 0.5
    @Published var isMuted = false
    @Published var brightness: Float = 0.5
    @Published var hasBrightness = false
    @Published var battery = BatteryInfo()
    @Published var media: MediaInfo?
    @Published var artwork: NSImage?
    @Published var hud: HUDKind?
    @Published var metrics = NotchMetrics.fallback

    private let volumeService = VolumeService()
    private let brightnessService = BrightnessService()
    private let batteryService = BatteryService()
    private let mediaService = MediaService()

    private var hudWork: DispatchWorkItem?
    private var brightnessTimer: Timer?
    private var lastVolumeWrite = Date.distantPast
    private var lastBrightnessWrite = Date.distantPast
    private var artworkURL: URL?

    // MARK: Layout

    var layout: IslandLayout {
        if isExpanded { return .expanded }
        if hud != nil { return .hud }
        if media?.isPlaying == true { return .live }
        return .idle
    }

    func size(for layout: IslandLayout) -> CGSize {
        switch layout {
        case .idle:     return CGSize(width: metrics.width, height: metrics.height)
        case .live:     return CGSize(width: metrics.width + 90, height: metrics.height)
        case .hud:      return CGSize(width: metrics.width + 130, height: metrics.height)
        case .expanded: return CGSize(width: 440, height: 200)
        }
    }

    // MARK: Start

    func start() {
        // Volume: start the service first so it knows the output device, then read it.
        volumeService.start()
        if let value = volumeService.volume() { volume = value }
        isMuted = volumeService.isMuted()
        volumeService.onChange = { [weak self] in self?.volumeChanged() }

        // Brightness: no change notification exists, so check a few times a second.
        if let value = brightnessService.read() {
            brightness = value
            hasBrightness = true
        }
        brightnessTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.pollBrightness()
        }

        // Battery
        if let info = batteryService.read() { battery = info }
        batteryService.onChange = { [weak self] in self?.batteryChanged() }
        batteryService.start()

        // Music / Spotify
        mediaService.onUpdate = { [weak self] info in self?.mediaChanged(info) }
        mediaService.start()
    }

    // MARK: Actions from the UI

    func setVolume(_ value: Float) {
        volume = value
        lastVolumeWrite = Date()
        if isMuted && value > 0 {
            isMuted = false
            volumeService.setMuted(false)
        }
        volumeService.setVolume(value)
    }

    func toggleMute() {
        isMuted.toggle()
        lastVolumeWrite = Date()
        volumeService.setMuted(isMuted)
    }

    func setBrightness(_ value: Float) {
        brightness = value
        lastBrightnessWrite = Date()
        brightnessService.write(value)
    }

    func togglePlayPause() {
        guard var current = media else { return }
        mediaService.send("playpause", to: current.app)
        current.isPlaying.toggle()
        media = current
    }

    func nextTrack() {
        guard let current = media else { return }
        mediaService.send("next track", to: current.app)
    }

    func previousTrack() {
        guard let current = media else { return }
        mediaService.send("previous track", to: current.app)
    }

    // MARK: Pop-ups

    func showHUD(_ kind: HUDKind, duration: TimeInterval = 1.8) {
        guard !isExpanded else { return }
        hud = kind
        hudWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.hud = nil }
        hudWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    // MARK: Updates coming from the system

    private func volumeChanged() {
        // Ignore the echo of our own slider drags.
        guard Date().timeIntervalSince(lastVolumeWrite) > 0.3 else { return }
        guard let value = volumeService.volume() else { return }
        let muted = volumeService.isMuted()
        let changed = abs(value - volume) > 0.001 || muted != isMuted
        volume = value
        isMuted = muted
        if changed { showHUD(.volume) }
    }

    private func pollBrightness() {
        guard Date().timeIntervalSince(lastBrightnessWrite) > 0.6 else { return }
        guard let value = brightnessService.read() else { return }
        let delta = abs(value - brightness)
        guard delta > 0.001 else { return }
        brightness = value
        hasBrightness = true
        // Brightness keys move in big steps; auto-brightness drifts in tiny ones.
        // Only the big steps get a pop-up.
        if delta >= 0.04 { showHUD(.brightness) }
    }

    private func batteryChanged() {
        guard let info = batteryService.read(), info != battery else { return }
        let wasPlugged = battery.isPluggedIn
        battery = info
        if info.isPluggedIn != wasPlugged {
            showHUD(info.isPluggedIn ? .charging : .unplugged, duration: 3)
        }
    }

    private func mediaChanged(_ info: MediaInfo?) {
        if info != media { media = info }
        if info?.artworkURL != artworkURL {
            artworkURL = info?.artworkURL
            artwork = nil
            if let url = artworkURL { loadArtwork(url) }
        }
    }

    private func loadArtwork(_ url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = NSImage(data: data) else { return }
            DispatchQueue.main.async {
                if self?.artworkURL == url { self?.artwork = image }
            }
        }.resume()
    }
}
