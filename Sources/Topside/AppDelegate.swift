import AppKit
import Combine
import ServiceManagement
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let model = IslandModel()
    private var panel: IslandPanel!
    private var screen: NSScreen?
    private var statusItem: NSStatusItem!
    private var loginItem: NSMenuItem!
    private var cancellables = Set<AnyCancellable>()
    private var monitors: [Any] = []
    private var expandWork: DispatchWorkItem?
    private var collapseWork: DispatchWorkItem?

    /// Big enough for the expanded island plus room for its shadow.
    private let panelSize = CGSize(width: 480, height: 230)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // no Dock icon

        let host = IslandHostingView(rootView: IslandView(model: model))
        host.sizingOptions = []
        panel = IslandPanel(contentView: host)
        positionPanel()
        panel.orderFrontRegardless()

        model.start()
        setupStatusItem()
        setupMouseTracking()

        // The panel only catches clicks while expanded; otherwise clicks pass straight through.
        model.$isExpanded
            .removeDuplicates()
            .sink { [weak self] expanded in
                self?.panel.ignoresMouseEvents = !expanded
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.positionPanel()
        }
    }

    // MARK: Position

    private func targetScreen() -> NSScreen? {
        NSScreen.screens.first(where: { $0.isBuiltIn }) ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func positionPanel() {
        guard let screen = targetScreen() else { return }
        self.screen = screen
        model.metrics = NotchMetrics.current(for: screen)

        let frame = NSRect(
            x: screen.frame.midX - panelSize.width / 2,
            y: screen.frame.maxY - panelSize.height,
            width: panelSize.width,
            height: panelSize.height
        )
        panel.setFrame(frame, display: true)
    }

    /// Where the island is drawn right now, in screen coordinates.
    private func islandRect() -> NSRect {
        guard let screen else { return .zero }
        let size = model.size(for: model.layout)
        return NSRect(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    // MARK: Hover

    private func setupMouseTracking() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]

        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            self?.mouseChanged()
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.mouseChanged()
            return event
        }) {
            monitors.append(local)
        }
    }

    private func isMouseInside() -> Bool {
        let margin: CGFloat = model.isExpanded ? 14 : 4
        // A negative inset grows the rect; it also reaches past the top of the screen,
        // so pushing the cursor into the very top edge still counts.
        let rect = islandRect().insetBy(dx: -margin, dy: -margin)
        return rect.contains(NSEvent.mouseLocation)
    }

    private func mouseChanged() {
        if isMouseInside() {
            collapseWork?.cancel()
            collapseWork = nil
            if !model.isExpanded && expandWork == nil {
                let work = DispatchWorkItem { [weak self] in
                    guard let self else { return }
                    self.expandWork = nil
                    if self.isMouseInside() { self.model.isExpanded = true }
                }
                expandWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
            }
        } else {
            expandWork?.cancel()
            expandWork = nil
            // Don't collapse while a slider is being dragged.
            if model.isExpanded && collapseWork == nil && NSEvent.pressedMouseButtons == 0 {
                let work = DispatchWorkItem { [weak self] in
                    guard let self else { return }
                    self.collapseWork = nil
                    if !self.isMouseInside() && NSEvent.pressedMouseButtons == 0 {
                        self.model.isExpanded = false
                    }
                }
                collapseWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
            }
        }
    }

    // MARK: Menu bar icon

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "waveform",
                                           accessibilityDescription: "Topside")

        let menu = NSMenu()
        menu.delegate = self

        loginItem = NSMenuItem(title: "Launch at Login",
                               action: #selector(toggleLaunchAtLogin(_:)),
                               keyEquivalent: "")
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Topside",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            NSSound.beep()
        }
    }
}
