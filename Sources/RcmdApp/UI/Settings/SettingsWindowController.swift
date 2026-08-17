import AppKit
import SwiftUI

struct SettingsActions {
    let assignApp: @MainActor (_ bundleIdentifier: String, _ letter: Character) -> Void
    let removeManualAssignment: @MainActor (_ letter: Character) -> Void
    let setKeyMappingMode: @MainActor (_ mode: KeyMappingMode) -> Void
    let setMinimizeActiveWindowOnRepeatedShortcut: @MainActor (_ enabled: Bool) -> Void
    let setLaunchAtLogin: @MainActor (_ enabled: Bool) -> Void
}

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let appState: AppStateModel
    private let actions: SettingsActions
    private var window: NSWindow?

    init(appState: AppStateModel, actions: SettingsActions) {
        self.appState = appState
        self.actions = actions
        super.init()
    }

    func show() {
        if window == nil {
            let hostingController = NSHostingController(rootView: SettingsView(appState: appState, actions: actions))
            let newWindow = NSWindow(contentViewController: hostingController)
            newWindow.title = L10n.tr("settings.windowTitle")
            newWindow.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            newWindow.setContentSize(NSSize(width: 860, height: 600))
            newWindow.minSize = NSSize(width: 780, height: 520)
            newWindow.isReleasedWhenClosed = false
            newWindow.delegate = self
            newWindow.center()
            window = newWindow
        }

        window?.makeKeyAndOrderFront(nil)
    }

    // A closed-but-retained window keeps its whole view tree in AppKit's window
    // maintenance work, which the system re-runs on every WindowServer
    // remote-context notification even while the app is idle. Drop it instead.
    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow, closing === window else {
            return
        }

        closing.delegate = nil

        Task { @MainActor [weak self] in
            self?.window = nil
        }
    }
}
