import AppKit
import SwiftUI

struct QuickStartActions {
    let requestAccessibilityPermission: @MainActor () -> Void
    let openSettings: @MainActor () -> Void
    let dismiss: @MainActor () -> Void
}

@MainActor
final class QuickStartWindowController: NSObject, NSWindowDelegate {
    private let appState: AppStateModel
    private let actions: QuickStartActions
    private var window: NSWindow?

    init(appState: AppStateModel, actions: QuickStartActions) {
        self.appState = appState
        self.actions = actions
        super.init()
    }

    func show() {
        if window == nil {
            let hostingController = NSHostingController(rootView: QuickStartView(appState: appState, actions: actions))
            let newWindow = NSWindow(contentViewController: hostingController)
            newWindow.title = L10n.tr("quickStart.windowTitle")
            newWindow.styleMask = [.titled, .closable, .miniaturizable]
            newWindow.setContentSize(NSSize(width: 660, height: 480))
            newWindow.minSize = NSSize(width: 620, height: 440)
            newWindow.isReleasedWhenClosed = false
            newWindow.delegate = self
            newWindow.center()
            window = newWindow
        }

        window?.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }

    // See SettingsWindowController.windowWillClose: a retained closed window
    // keeps paying for AppKit window maintenance while the app sits idle.
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
