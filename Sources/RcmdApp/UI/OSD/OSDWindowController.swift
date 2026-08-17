import AppKit
import SwiftUI

struct OSDActions {
    let focusWindow: @MainActor (WindowInfo) -> Void
    let refreshWindows: @MainActor () -> Void
    let closeSearch: @MainActor () -> Void
}

@MainActor
final class OSDWindowController: NSObject, NSWindowDelegate {
    private let appState: AppStateModel
    private let actions: OSDActions
    private var panel: NSPanel?
    private var panelTeardownWorkItem: DispatchWorkItem?
    private let panelIdleTeardownDelay: TimeInterval = 60

    init(appState: AppStateModel, actions: OSDActions) {
        self.appState = appState
        self.actions = actions
        super.init()
    }

    func show() {
        cancelPanelTeardown()
        let panel = panel ?? makePanel()
        self.panel = panel
        position(panel, preferredSize: NSSize(width: 720, height: 430))
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.08
            panel.animator().alphaValue = 1
        }
    }

    func showSearch() {
        cancelPanelTeardown()
        let panel = panel ?? makePanel()
        self.panel = panel

        if !panel.isVisible {
            position(panel, preferredSize: NSSize(width: 720, height: 430))
        }

        panel.alphaValue = 1
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func activateSearchIfNeeded() {
        guard let panel, panel.isVisible else {
            showSearch()
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func resignSearchIfNeeded() {
        guard let panel, panel.isVisible else {
            return
        }

        panel.orderFrontRegardless()
    }

    func focusSearch() {
        guard appState.osdMode == .windowSearch, let panel, panel.isVisible else {
            return
        }

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        guard let panel, panel.isVisible else {
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.06
            panel.animator().alphaValue = 0
        } completionHandler: {
            Task { @MainActor [weak self] in
                panel.orderOut(nil)
                panel.alphaValue = 1
                self?.schedulePanelTeardown()
            }
        }
    }

    func hideImmediately() {
        guard let panel else {
            return
        }

        panel.contentView?.layer?.removeAllAnimations()
        panel.animations = [:]
        panel.alphaValue = 0
        panel.orderOut(nil)
        panel.alphaValue = 1
        schedulePanelTeardown()
    }

    // The hidden panel keeps a full SwiftUI view tree that AppKit walks on every
    // WindowServer remote-context notification, so an idle app never stops
    // paying for it. Keep the panel warm for repeated shortcuts, then drop it.
    private func schedulePanelTeardown() {
        cancelPanelTeardown()

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.tearDownPanelIfHidden()
            }
        }
        panelTeardownWorkItem = workItem

        DispatchQueue.main.asyncAfter(deadline: .now() + panelIdleTeardownDelay, execute: workItem)
    }

    private func cancelPanelTeardown() {
        panelTeardownWorkItem?.cancel()
        panelTeardownWorkItem = nil
    }

    private func tearDownPanelIfHidden() {
        panelTeardownWorkItem = nil

        guard let panel, !panel.isVisible else {
            return
        }

        panel.delegate = nil
        panel.close()
        self.panel = nil
    }

    private func makePanel() -> NSPanel {
        let hostingController = NSHostingController(rootView: OSDView(appState: appState, actions: actions))
        let panel = OSDPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 260),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.contentViewController = hostingController
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.delegate = self

        return panel
    }

    func windowDidResignKey(_ notification: Notification) {
        guard appState.osdMode == .windowSearch else {
            return
        }

        actions.closeSearch()
    }

    private func position(_ panel: NSPanel) {
        position(panel, preferredSize: nil)
    }

    private func position(_ panel: NSPanel, preferredSize: NSSize?) {
        let fittingSize: NSSize
        if let preferredSize {
            fittingSize = preferredSize
        } else {
            panel.contentViewController?.view.layoutSubtreeIfNeeded()
            fittingSize = panel.contentViewController?.view.fittingSize ?? NSSize(width: 620, height: 260)
        }
        let screenFrame = targetScreenFrame()
        let horizontalPadding: CGFloat = 32
        let verticalPadding: CGFloat = 28
        let maxWidth = max(360, screenFrame.width - horizontalPadding * 2)
        let maxHeight = max(120, min(640, screenFrame.height - verticalPadding * 2))
        let rawWidth = fittingSize.width
        let rawHeight = fittingSize.height
        let width = min(max(rawWidth, 420), min(maxWidth, 720))
        let height = min(max(rawHeight, 120), maxHeight)
        let originX = screenFrame.midX - width / 2
        let originY = screenFrame.maxY - height - verticalPadding

        panel.setFrame(
            NSRect(x: originX, y: originY, width: width, height: height),
            display: true
        )
    }

    private func targetScreenFrame() -> NSRect {
        let mouseLocation = NSEvent.mouseLocation

        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) {
            return screen.visibleFrame
        }

        return NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? NSRect(x: 0, y: 0, width: 720, height: 480)
    }
}

private final class OSDPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }
}
