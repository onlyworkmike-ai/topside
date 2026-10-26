import AppKit
import SwiftUI

// MARK: - Plain data types

enum MediaApp: Equatable {
    case music
    case spotify

    var bundleID: String { self == .music ? "com.apple.Music" : "com.spotify.client" }
    var scriptName: String { self == .music ? "Music" : "Spotify" }
}

struct MediaInfo: Equatable {
    var app: MediaApp
    var title: String
    var artist: String
    var isPlaying: Bool
    var artworkURL: URL?
}

struct BatteryInfo: Equatable {
    var percent: Int = 100
    var isCharging = false
    var isPluggedIn = false
}

/// Short pop-ups the island shows by itself (like the iPhone's live activities).
enum HUDKind: Equatable {
    case volume
    case brightness
    case charging
    case unplugged
}

/// The four shapes the island can take.
enum IslandLayout: Equatable {
    case idle      // resting: looks like a notch
    case live      // music is playing: slightly wider, art on the left, waveform on the right
    case hud       // a quick pop-up (volume, brightness, charger)
    case expanded  // hovering: full panel

    var radii: (top: CGFloat, bottom: CGFloat) {
        switch self {
        case .idle, .live, .hud: return (6, 12)
        case .expanded: return (19, 26)
        }
    }
}

// MARK: - Notch size

struct NotchMetrics: Equatable {
    var width: CGFloat
    var height: CGFloat
    var hasHardwareNotch: Bool

    static let fallback = NotchMetrics(width: 190, height: 25, hasHardwareNotch: false)

    static func current(for screen: NSScreen) -> NotchMetrics {
        // Macs with a real notch (2021+ MacBook Pro, M2+ Air): match its size.
        let inset = screen.safeAreaInsets.top
        if inset > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let width = screen.frame.width - left.width - right.width
            return NotchMetrics(width: width + 8, height: inset, hasHardwareNotch: true)
        }
        // Macs without one (like the M1 Air): a pill as tall as the menu bar.
        let menuBar = screen.frame.maxY - screen.visibleFrame.maxY
        return NotchMetrics(width: 190, height: max(menuBar, 24), hasHardwareNotch: false)
    }
}

extension NSScreen {
    var isBuiltIn: Bool {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return false
        }
        return CGDisplayIsBuiltin(CGDirectDisplayID(number.uint32Value)) != 0
    }
}

// MARK: - The notch shape

/// Flat top edge that flares outward at the corners, rounded at the bottom.
/// This is the same silhouette as the hardware notch.
struct NotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let top = topCornerRadius
        let bottom = bottomCornerRadius

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + top, y: rect.minY + top),
            control: CGPoint(x: rect.minX + top, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + top, y: rect.maxY - bottom))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + top + bottom, y: rect.maxY),
            control: CGPoint(x: rect.minX + top, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - top - bottom, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - top, y: rect.maxY - bottom),
            control: CGPoint(x: rect.maxX - top, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY + top))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - top, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        return path
    }
}
