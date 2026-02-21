//
//  TextPaster.swift
//  Murmurix
//

import Foundation
import AppKit
import Carbon

final class TextPaster {
    struct FocusContext {
        enum Status: String {
            case success
            case noFocusedElement
            case focusedElementTypeMismatch
            case roleUnavailable
            case roleTypeMismatch
        }

        let status: Status
        let appName: String?
        let role: String?
        let subrole: String?
        let isEditable: Bool?
        let isTextInput: Bool

        var lookupFailed: Bool {
            status != .success
        }

        var summary: String {
            let app = appName ?? "unknown"
            let roleValue = role ?? "nil"
            let subroleValue = subrole ?? "nil"
            let editableValue = isEditable.map { $0 ? "true" : "false" } ?? "nil"
            return "status=\(status.rawValue), app=\(app), role=\(roleValue), subrole=\(subroleValue), editable=\(editableValue), textInput=\(isTextInput)"
        }
    }

    private static let pasteDelay: TimeInterval = 0.05
    private static let clipboardRestoreDelay: TimeInterval = 0.5

    /// Check if the current focused element is a text input field
    static func isTextFieldFocused() -> Bool {
        focusedContext().isTextInput
    }

    static func focusedContext() -> FocusContext {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?

        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard result == .success, let element = focusedElement else {
            return FocusContext(
                status: .noFocusedElement,
                appName: nil,
                role: nil,
                subrole: nil,
                isEditable: nil,
                isTextInput: false
            )
        }

        guard CFGetTypeID(element) == AXUIElementGetTypeID() else {
            return FocusContext(
                status: .focusedElementTypeMismatch,
                appName: nil,
                role: nil,
                subrole: nil,
                isEditable: nil,
                isTextInput: false
            )
        }
        let axElement = unsafeBitCast(element, to: AXUIElement.self)
        let appName = appName(for: axElement)

        // Get the role of the focused element
        var role: AnyObject?
        let roleResult = AXUIElementCopyAttributeValue(
            axElement,
            kAXRoleAttribute as CFString,
            &role
        )

        guard roleResult == .success else {
            return FocusContext(
                status: .roleUnavailable,
                appName: appName,
                role: nil,
                subrole: nil,
                isEditable: editableValue(for: axElement),
                isTextInput: false
            )
        }

        guard let roleString = role as? String else {
            return FocusContext(
                status: .roleTypeMismatch,
                appName: appName,
                role: nil,
                subrole: nil,
                isEditable: editableValue(for: axElement),
                isTextInput: false
            )
        }

        // Text input roles
        let textRoles: Set<String> = [
            kAXTextFieldRole as String,
            kAXTextAreaRole as String,
            kAXComboBoxRole as String,
            "AXSearchField"  // kAXSearchFieldRole not always available
        ]

        let editable = editableValue(for: axElement)
        let subrole = stringValue(for: axElement, attribute: kAXSubroleAttribute as CFString)
        let isTextInput = textRoles.contains(roleString) || editable == true

        return FocusContext(
            status: .success,
            appName: appName,
            role: roleString,
            subrole: subrole,
            isEditable: editable,
            isTextInput: isTextInput
        )
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

    private static func appName(for element: AXUIElement) -> String? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else { return nil }
        return NSRunningApplication(processIdentifier: pid)?.localizedName
    }

    private static func stringValue(for element: AXUIElement, attribute: CFString) -> String? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return value as? String
    }

    private static func editableValue(for element: AXUIElement) -> Bool? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            element,
            "AXEditable" as CFString,
            &value
        )
        guard result == .success else { return nil }
        return value as? Bool
    }

    private static func scheduleMain(after delay: TimeInterval, execute: @MainActor @escaping () -> Void) {
        let delayNanoseconds = UInt64(delay * 1_000_000_000)
        Task { @MainActor in
            if delayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }
            execute()
        }
    }
}
