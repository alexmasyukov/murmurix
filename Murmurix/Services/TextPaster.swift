//
//  TextPaster.swift
//  Murmurix
//

import Foundation
import AppKit
import Carbon

final class TextPaster {
    private static let pasteDelay: TimeInterval = 0.05
    private static let clipboardRestoreDelay: TimeInterval = 0.5

    /// Check if the current focused element is a text input field
    static func isTextFieldFocused() -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?

        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard result == .success, let element = focusedElement else {
            return false
        }

        guard CFGetTypeID(element) == AXUIElementGetTypeID() else {
            return false
        }
        let axElement = unsafeBitCast(element, to: AXUIElement.self)

        // Get the role of the focused element
        var role: AnyObject?
        let roleResult = AXUIElementCopyAttributeValue(
            axElement,
            kAXRoleAttribute as CFString,
            &role
        )

        guard roleResult == .success, let roleString = role as? String else {
            return false
        }

        // Text input roles
        let textRoles: Set<String> = [
            kAXTextFieldRole as String,
            kAXTextAreaRole as String,
            kAXComboBoxRole as String,
            "AXSearchField"  // kAXSearchFieldRole not always available
        ]

        if textRoles.contains(roleString) {
            return true
        }

        // Also check if element has AXValue attribute and is editable
        // This catches custom text fields in apps like Electron
        var isEditable: AnyObject?
        let editableResult = AXUIElementCopyAttributeValue(
            axElement,
            "AXEditable" as CFString,
            &isEditable
        )

        if editableResult == .success, let editable = isEditable as? Bool, editable {
            return true
        }

        return false
    }

    /// Paste text by putting it in clipboard and simulating Cmd+V
    static func paste(_ text: String) {
        // Save current clipboard content
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        // Put new text in clipboard
        setPasteboardString(text, on: pasteboard)

        // Small delay to ensure clipboard is ready
        scheduleMain(after: pasteDelay) {
            // Simulate Cmd+V
            simulatePaste()

            // Optionally restore previous clipboard after a delay
            if let previous = previousContents {
                scheduleMain(after: clipboardRestoreDelay) {
                    setPasteboardString(previous, on: pasteboard)
                }
            }
        }
    }

    private static func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        // V key = keycode 9
        let vKeyCode: CGKeyCode = 9

        // Key down with Command
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        keyDown?.flags = .maskCommand

        // Key up
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        keyUp?.flags = .maskCommand

        // Post events
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }

    private static func setPasteboardString(_ text: String, on pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private static func scheduleMain(after delay: TimeInterval, execute: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: execute)
    }
}
