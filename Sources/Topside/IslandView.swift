import SwiftUI

struct IslandView: View {
    @ObservedObject var model: IslandModel

    var body: some View {
        let layout = model.layout
        let size = model.size(for: layout)
        let radii = layout.radii
        let expanded = layout == .expanded
        let topPadding: CGFloat = expanded ? (model.metrics.hasHardwareNotch ? model.metrics.height + 6 : 20) : 0

        ZStack(alignment: .top) {
            NotchShape(topCornerRadius: radii.top, bottomCornerRadius: radii.bottom)
                .fill(Color.black)

            content(for: layout)
                .padding(.horizontal, radii.top + (expanded ? 22 : 12))
                .padding(.top, topPadding)
                .padding(.bottom, expanded ? 16 : 0)
                .frame(width: size.width, height: size.height, alignment: expanded ? .top : .center)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(NotchShape(topCornerRadius: radii.top, bottomCornerRadius: radii.bottom))
        .shadow(color: Color.black.opacity(expanded ? 0.4 : 0), radius: 14, x: 0, y: 6)
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: layout)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: Content per layout

    @ViewBuilder
    private func content(for layout: IslandLayout) -> some View {
        switch layout {
        case .idle:
            Color.clear
        case .live:
            liveContent.transition(.opacity)
        case .hud:
            if let kind = model.hud {
                hudContent(kind).transition(.opacity)
            }
        case .expanded:
            expandedContent.transition(.opacity)
        }
    }

    private var liveContent: some View {
        HStack(spacing: 0) {
            ArtworkView(image: model.artwork, size: 17)
            Spacer(minLength: 0)
            WaveformView()
        }
    }

    // MARK: Pop-ups

    @ViewBuilder
    private func hudContent(_ kind: HUDKind) -> some View {
        switch kind {
        case .volume:
            hudRow(icon: volumeIcon, tint: Color.white) {
                MiniBar(value: model.isMuted ? 0 : Double(model.volume))
            }
        case .brightness:
            hudRow(icon: "sun.max.fill", tint: Color.white) {
                MiniBar(value: Double(model.brightness))
            }
        case .charging:
            hudRow(icon: "bolt.fill", tint: Color.green) {
                percentText
            }
        case .unplugged:
            hudRow(icon: "bolt.slash.fill", tint: Color.white) {
                percentText
            }
        }
    }

    private func hudRow<Trailing: View>(
        icon: String,
        tint: Color,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
            Spacer(minLength: 0)
            trailing()
        }
    }

    private var percentText: some View {
        Text("\(model.battery.percent)%")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.white)
    }

    private var volumeIcon: String {
        if model.isMuted || model.volume <= 0.001 { return "speaker.slash.fill" }
        if model.volume < 0.34 { return "speaker.wave.1.fill" }
        if model.volume < 0.67 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    // MARK: Expanded panel

    private var expandedContent: some View {
        VStack(spacing: 12) {
            mediaRow
            VStack(spacing: 8) {
                sliderRow(icon: volumeIcon,
                          value: volumeBinding,
                          enabled: true,
                          onIconTap: { model.toggleMute() })
                sliderRow(icon: "sun.max.fill",
                          value: brightnessBinding,
                          enabled: model.hasBrightness,
                          onIconTap: nil)
            }
            footer
        }
    }

    private var volumeBinding: Binding<Double> {
        Binding(
            get: { Double(model.volume) },
            set: { model.setVolume(Float($0)) }
        )
    }

    private var brightnessBinding: Binding<Double> {
        Binding(
            get: { Double(model.brightness) },
            set: { model.setBrightness(Float($0)) }
        )
    }

    @ViewBuilder
    private var mediaRow: some View {
        if let media = model.media {
            HStack(spacing: 12) {
                ArtworkView(image: model.artwork, size: 50)
                VStack(alignment: .leading, spacing: 2) {
                    Text(media.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                    Text(media.artist)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                HStack(spacing: 18) {
                    controlButton("backward.fill", size: 15) { model.previousTrack() }
                    controlButton(media.isPlaying ? "pause.fill" : "play.fill", size: 21) { model.togglePlayPause() }
                    controlButton("forward.fill", size: 15) { model.nextTrack() }
                }
            }
            .frame(height: 50)
        } else {
            HStack(spacing: 12) {
                ArtworkView(image: nil, size: 50)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nothing playing")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white)
                    Text("Play something in Music or Spotify")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .frame(height: 50)
        }
    }

    private func controlButton(_ symbol: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size))
                .foregroundStyle(Color.white)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sliderRow(
        icon: String,
        value: Binding<Double>,
        enabled: Bool,
        onIconTap: (() -> Void)?
    ) -> some View {
        HStack(spacing: 10) {
            Button {
                onIconTap?()
            } label: {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(enabled ? 0.9 : 0.35))
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Slider(value: value, in: 0...1)
                .controlSize(.small)
                .tint(Color.white)
                .disabled(!enabled)
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: model.battery.isCharging ? "bolt.fill" : batteryIcon)
                .foregroundStyle(model.battery.isCharging ? Color.green : Color.white.opacity(0.8))
            Text("\(model.battery.percent)%")
            Spacer()
            TimelineView(.periodic(from: Date(), by: 1)) { context in
                Text(context.date, format: .dateTime.weekday(.abbreviated).hour().minute())
            }
        }
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(Color.white.opacity(0.7))
    }

    private var batteryIcon: String {
        switch model.battery.percent {
        case ..<13: return "battery.0"
        case ..<38: return "battery.25"
        case ..<63: return "battery.50"
        case ..<88: return "battery.75"
        default:    return "battery.100"
        }
    }
}

// MARK: - Small pieces

struct ArtworkView: View {
    let image: NSImage?
    let size: CGFloat

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Color.pink, Color.purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.45, weight: .semibold))
                        .foregroundStyle(Color.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}

struct WaveformView: View {
    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<4, id: \.self) { index in
                    let wave = abs(sin(time * 4 + Double(index) * 0.9))
                    Capsule()
                        .fill(Color.green)
                        .frame(width: 2.5, height: CGFloat(4 + 9 * wave))
                }
            }
            .frame(height: 14)
        }
    }
}

struct MiniBar: View {
    var value: Double

    var body: some View {
        let clamped = CGFloat(min(max(value, 0), 1))
        ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.25))
            Capsule()
                .fill(Color.white)
                .frame(width: max(4, 56 * clamped))
        }
        .frame(width: 56, height: 4)
        .animation(.easeOut(duration: 0.12), value: value)
    }
}
