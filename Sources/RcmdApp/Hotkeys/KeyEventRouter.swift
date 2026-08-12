import ApplicationServices
import Foundation

enum KeyEventRouteDecision: Equatable {
    case passThrough
    case suppress
    case shortcut(KeyShortcut)
    case windowSearchAction(WindowSearchKeyAction)
    case rightCommandChanged(Bool)
}

struct KeyEventRoutingInput {
    let event: KeyEvent
    let isAutorepeat: Bool
    let isWindowSearchActive: Bool
    let keyMappingMode: KeyMappingMode
    let printableText: String?
}

struct KeyEventRouter {
    private var rightCommandHeld = false
    private var rightOptionHeld = false
    private var shiftHeld = false
    private var consumedKeyCodes = Set<Int64>()

    var isRightCommandHeld: Bool {
        rightCommandHeld
    }

    /// Shift is what the system and apps build their own `⌘⇧` shortcuts on, so rcmd stays
    /// out of the way while it is held: no overlay, and no key capture either.
    private var isTriggerActive: Bool {
        rightCommandHeld && !shiftHeld
    }

    mutating func route(_ input: KeyEventRoutingInput) -> KeyEventRouteDecision {
        let wasTriggerActive = isTriggerActive
        shiftHeld = input.event.shiftDown
        reconcileModifierState(from: input.event)

        if input.event.kind == .flagsChanged {
            if input.event.isRightCommandKey {
                updateRightCommandHeld(input.event)
            } else if input.event.isRightOptionKey {
                rightOptionHeld = input.event.optionDown
            }

            guard isTriggerActive != wasTriggerActive else {
                return .passThrough
            }

            return .rightCommandChanged(isTriggerActive)
        }

        if input.event.kind == .keyUp, consumedKeyCodes.remove(input.event.keyCode) != nil {
            return .suppress
        }

        if input.event.kind == .keyDown, input.isWindowSearchActive {
            if let decision = routeWindowSearchKeyDown(input) {
                return decision
            }
        }

        guard input.event.kind == .keyDown,
              isTriggerActive,
              !input.isAutorepeat else {
            return .passThrough
        }

        if input.event.keyCode == KeyCode.tab {
            consumedKeyCodes.insert(input.event.keyCode)
            return .shortcut(KeyShortcut(kind: .cycleWindow, letter: "\t", keyCode: input.event.keyCode, timestamp: input.event.timestamp))
        }

        if input.event.keyCode == KeyCode.space {
            consumedKeyCodes.insert(input.event.keyCode)
            return .shortcut(KeyShortcut(kind: .openWindowSearch, letter: " ", keyCode: input.event.keyCode, timestamp: input.event.timestamp))
        }

        if let letter = KeyboardLayout.letter(for: input.event.keyCode, mode: input.keyMappingMode) {
            consumedKeyCodes.insert(input.event.keyCode)
            let shortcutKind: KeyShortcutKind = rightOptionHeld ? .assign : .activate
            return .shortcut(KeyShortcut(kind: shortcutKind, letter: letter, keyCode: input.event.keyCode, timestamp: input.event.timestamp))
        }

        return .passThrough
    }

    mutating func resetRightCommandState() -> Bool {
        let wasHeld = rightCommandHeld
        rightCommandHeld = false
        consumedKeyCodes.removeAll()

        return wasHeld
    }

    mutating func resetAll() {
        _ = resetRightCommandState()
        rightOptionHeld = false
        shiftHeld = false
    }

    mutating func reconcileModifierStateFromSystemFlags(_ flags: CGEventFlags) -> Bool {
        let wasTriggerActive = isTriggerActive
        shiftHeld = flags.contains(.maskShift)

        if rightCommandHeld, !flags.contains(.maskCommand) {
            _ = resetRightCommandState()
        }

        if rightOptionHeld, !flags.contains(.maskAlternate) {
            rightOptionHeld = false
        }

        return wasTriggerActive && !isTriggerActive
    }

    private mutating func updateRightCommandHeld(_ event: KeyEvent) {
        rightCommandHeld = event.commandDown

        if !rightCommandHeld {
            rightOptionHeld = false
            consumedKeyCodes.removeAll()
        }
    }

    private mutating func routeWindowSearchKeyDown(_ input: KeyEventRoutingInput) -> KeyEventRouteDecision? {
        if shouldPassThroughSystemShortcut(input.event) {
            return nil
        }

        if rightCommandHeld,
           !input.isAutorepeat,
           input.event.keyCode == KeyCode.space {
            consumedKeyCodes.insert(input.event.keyCode)
            return .shortcut(KeyShortcut(kind: .openWindowSearch, letter: " ", keyCode: input.event.keyCode, timestamp: input.event.timestamp))
        }

        switch input.event.keyCode {
        case KeyCode.arrowUp:
            return .windowSearchAction(.moveUp)
        case KeyCode.arrowDown:
            return .windowSearchAction(.moveDown)
        case KeyCode.return, KeyCode.keypadEnter:
            return .windowSearchAction(.submit)
        case KeyCode.escape:
            return .windowSearchAction(.close)
        case KeyCode.delete:
            return .windowSearchAction(.deleteBackward)
        default:
            break
        }

        if let printableText = input.printableText {
            return .windowSearchAction(.insertText(printableText))
        }

        if let letter = KeyboardLayout.letter(for: input.event.keyCode, mode: input.keyMappingMode) {
            return .windowSearchAction(.insertText(String(letter)))
        }

        return nil
    }

    private func shouldPassThroughSystemShortcut(_ event: KeyEvent) -> Bool {
        let flags = CGEventFlags(rawValue: event.rawFlags)

        if flags.contains(.maskControl) || flags.contains(.maskAlternate) {
            return true
        }

        if flags.contains(.maskCommand), !rightCommandHeld {
            return true
        }

        return false
    }

    private mutating func reconcileModifierState(from event: KeyEvent) {
        guard event.kind == .keyDown || event.kind == .keyUp else {
            return
        }

        if rightCommandHeld, !event.commandDown {
            _ = resetRightCommandState()
        }

        if rightOptionHeld, !event.optionDown {
            rightOptionHeld = false
        }
    }
}
