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
        let appBundleIdentifier: String?
        let role: String?
        let subrole: String?
        let axErrorCode: Int32?
        let isEditable: Bool?
        let hasValueAttribute: Bool?
        let hasInsertionPointLineNumber: Bool?
        let hasSelectedTextRange: Bool?
        let usedKnownAppFallback: Bool
        let isTextInput: Bool

        init(
            status: Status,
            appName: String? = nil,
            appBundleIdentifier: String? = nil,
            role: String? = nil,
            subrole: String? = nil,
            axErrorCode: Int32? = nil,
            isEditable: Bool? = nil,
            hasValueAttribute: Bool? = nil,
            hasInsertionPointLineNumber: Bool? = nil,
            hasSelectedTextRange: Bool? = nil,
            usedKnownAppFallback: Bool = false,
            isTextInput: Bool
        ) {
            self.status = status
            self.appName = appName
            self.appBundleIdentifier = appBundleIdentifier
            self.role = role
            self.subrole = subrole
            self.axErrorCode = axErrorCode
            self.isEditable = isEditable
            self.hasValueAttribute = hasValueAttribute
            self.hasInsertionPointLineNumber = hasInsertionPointLineNumber
            self.hasSelectedTextRange = hasSelectedTextRange
            self.usedKnownAppFallback = usedKnownAppFallback
            self.isTextInput = isTextInput
        }

        var lookupFailed: Bool {
            status != .success
        }

        var summary: String {
            let app = appName ?? "unknown"
            let bundle = appBundleIdentifier ?? "unknown"
            let roleValue = role ?? "nil"
            let subroleValue = subrole ?? "nil"
            let axError = axErrorCode.map(String.init) ?? "nil"
            let editableValue = isEditable.map { $0 ? "true" : "false" } ?? "nil"
            let valueAttribute = hasValueAttribute.map { $0 ? "true" : "false" } ?? "nil"
            let insertionPoint = hasInsertionPointLineNumber.map { $0 ? "true" : "false" } ?? "nil"
            let selectedTextRange = hasSelectedTextRange.map { $0 ? "true" : "false" } ?? "nil"
            let knownFallback = usedKnownAppFallback ? "true" : "false"
            return "status=\(status.rawValue), app=\(app), bundle=\(bundle), role=\(roleValue), subrole=\(subroleValue), axError=\(axError), editable=\(editableValue), hasValue=\(valueAttribute), hasInsertionLine=\(insertionPoint), hasSelectedTextRange=\(selectedTextRange), knownAppFallback=\(knownFallback), textInput=\(isTextInput)"
        }
    }

    private static let pasteDelay: TimeInterval = 0.05
    private static let clipboardRestoreDelay: TimeInterval = 0.5
    private static let textInputRoles: Set<String> = [
        kAXTextFieldRole as String,
        kAXTextAreaRole as String,
        kAXComboBoxRole as String,
        "AXSearchField"
    ]
    private static let extendedTextInputRoles: Set<String> = [
        "AXWebArea",
        "AXGroup"
    ]
    private static let knownTextInputHostBundleIdentifiers: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.microsoft.VSCode",
        "com.anthropic.claudefordesktop",
        "com.todesktop.230313mzl4w4u92", // Cursor
        "com.exafunction.windsurf"
    ]
    private static let knownTextInputHostBundlePrefixes: [String] = [
        "com.jetbrains."
    ]
    private static let knownTextInputHostNameFragments: [String] = [
        "terminal",
        "iterm",
        "webstorm",
        "intellij",
        "pycharm",
        "goland",
        "clion",
        "datagrip",
        "rubymine",
        "rider",
        "phpstorm",
        "fleet",
        "claude",
        "cursor",
        "windsurf"
    ]

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
            let frontmostApp = frontmostAppIdentity()
            let inference = inferTextInput(
                status: .noFocusedElement,
                role: nil,
                editable: nil,
                hasValueAttribute: false,
                hasInsertionPointLineNumber: false,
                hasSelectedTextRange: false,
                appName: frontmostApp.name,
                appBundleIdentifier: frontmostApp.bundleIdentifier
            )
            return FocusContext(
                status: .noFocusedElement,
                appName: frontmostApp.name,
                appBundleIdentifier: frontmostApp.bundleIdentifier,
                role: nil,
                subrole: nil,
                axErrorCode: result.rawValue,
                isEditable: nil,
                hasValueAttribute: false,
                hasInsertionPointLineNumber: false,
                hasSelectedTextRange: false,
                usedKnownAppFallback: inference.knownAppFallbackUsed,
                isTextInput: inference.isTextInput
            )
        }

        guard CFGetTypeID(element) == AXUIElementGetTypeID() else {
            return FocusContext(
                status: .focusedElementTypeMismatch,
                appName: nil,
                appBundleIdentifier: nil,
                role: nil,
                subrole: nil,
                axErrorCode: nil,
                isEditable: nil,
                isTextInput: false
            )
        }
        let axElement = unsafeBitCast(element, to: AXUIElement.self)
        let app = appIdentity(for: axElement)
        let editable = editableValue(for: axElement)
        let hasValue = hasAttribute(axElement, attribute: kAXValueAttribute as CFString)
        let hasInsertionPointLineNumber = intValue(for: axElement, attribute: "AXInsertionPointLineNumber" as CFString) != nil
        let hasSelectedTextRange = hasAttribute(axElement, attribute: "AXSelectedTextRange" as CFString)

        // Get the role of the focused element
        var role: AnyObject?
        let roleResult = AXUIElementCopyAttributeValue(
            axElement,
            kAXRoleAttribute as CFString,
            &role
        )

        guard roleResult == .success else {
            let inference = inferTextInput(
                status: .roleUnavailable,
                role: nil,
                editable: editable,
                hasValueAttribute: hasValue,
                hasInsertionPointLineNumber: hasInsertionPointLineNumber,
                hasSelectedTextRange: hasSelectedTextRange,
                appName: app.name,
                appBundleIdentifier: app.bundleIdentifier
            )
            return FocusContext(
                status: .roleUnavailable,
                appName: app.name,
                appBundleIdentifier: app.bundleIdentifier,
                role: nil,
                subrole: nil,
                axErrorCode: roleResult.rawValue,
                isEditable: editable,
                hasValueAttribute: hasValue,
                hasInsertionPointLineNumber: hasInsertionPointLineNumber,
                hasSelectedTextRange: hasSelectedTextRange,
                usedKnownAppFallback: inference.knownAppFallbackUsed,
                isTextInput: inference.isTextInput
            )
        }

        guard let roleString = role as? String else {
            let inference = inferTextInput(
                status: .roleTypeMismatch,
                role: nil,
                editable: editable,
                hasValueAttribute: hasValue,
                hasInsertionPointLineNumber: hasInsertionPointLineNumber,
                hasSelectedTextRange: hasSelectedTextRange,
                appName: app.name,
                appBundleIdentifier: app.bundleIdentifier
            )
            return FocusContext(
                status: .roleTypeMismatch,
                appName: app.name,
                appBundleIdentifier: app.bundleIdentifier,
                role: nil,
                subrole: nil,
                axErrorCode: nil,
                isEditable: editable,
                hasValueAttribute: hasValue,
                hasInsertionPointLineNumber: hasInsertionPointLineNumber,
                hasSelectedTextRange: hasSelectedTextRange,
                usedKnownAppFallback: inference.knownAppFallbackUsed,
                isTextInput: inference.isTextInput
            )
        }

        let subrole = stringValue(for: axElement, attribute: kAXSubroleAttribute as CFString)
        let inference = inferTextInput(
            status: .success,
            role: roleString,
            editable: editable,
            hasValueAttribute: hasValue,
            hasInsertionPointLineNumber: hasInsertionPointLineNumber,
            hasSelectedTextRange: hasSelectedTextRange,
            appName: app.name,
            appBundleIdentifier: app.bundleIdentifier
        )

        return FocusContext(
            status: .success,
            appName: app.name,
            appBundleIdentifier: app.bundleIdentifier,
            role: roleString,
            subrole: subrole,
            axErrorCode: nil,
            isEditable: editable,
            hasValueAttribute: hasValue,
            hasInsertionPointLineNumber: hasInsertionPointLineNumber,
            hasSelectedTextRange: hasSelectedTextRange,
            usedKnownAppFallback: inference.knownAppFallbackUsed,
            isTextInput: inference.isTextInput
        )
    }

    static func inferTextInput(
        status: FocusContext.Status,
        role: String?,
        editable: Bool?,
        hasValueAttribute: Bool,
        hasInsertionPointLineNumber: Bool,
        hasSelectedTextRange: Bool,
        appName: String?,
        appBundleIdentifier: String?
    ) -> (isTextInput: Bool, knownAppFallbackUsed: Bool) {
        let roleMatchesTextInput = role.map { textInputRoles.contains($0) } ?? false
        if roleMatchesTextInput {
            return (true, false)
        }

        let roleIsExtendedTextCandidate = role.map { extendedTextInputRoles.contains($0) } ?? false
        let extendedSignalsTextInput = editable == true || hasInsertionPointLineNumber || hasSelectedTextRange
        if roleIsExtendedTextCandidate && extendedSignalsTextInput {
            return (true, false)
        }

        // Generic fallback for many Electron/web wrappers that correctly expose AXEditable.
        if editable == true {
            return (true, false)
        }

        let knownAppHost = isKnownTextInputHost(appName: appName, bundleIdentifier: appBundleIdentifier)
        let roleUnavailableOrAmbiguous = status != .success
            || role == nil
            || role == "AXApplication"
            || role == "AXUnknown"
            || role == "AXGroup"
            || role == "AXWebArea"

        if knownAppHost && roleUnavailableOrAmbiguous {
            return (true, true)
        }

        // Keep AXValue as diagnostic only to avoid false positives on non-editable web areas.
        _ = hasValueAttribute
        return (false, false)
    }

    static func isKnownTextInputHost(appName: String?, bundleIdentifier: String?) -> Bool {
        if let bundleIdentifier {
            if bundleIdentifier == Bundle.main.bundleIdentifier {
                return false
            }
            if knownTextInputHostBundleIdentifiers.contains(bundleIdentifier) {
                return true
            }
            if knownTextInputHostBundlePrefixes.contains(where: { bundleIdentifier.hasPrefix($0) }) {
                return true
            }
        }

        guard let appName else { return false }
        let normalizedName = appName.lowercased()
        return knownTextInputHostNameFragments.contains { normalizedName.contains($0) }
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

    private static func appIdentity(for element: AXUIElement) -> (name: String?, bundleIdentifier: String?) {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else { return (nil, nil) }
        let app = NSRunningApplication(processIdentifier: pid)
        return (app?.localizedName, app?.bundleIdentifier)
    }

    private static func frontmostAppIdentity() -> (name: String?, bundleIdentifier: String?) {
        let app = NSWorkspace.shared.frontmostApplication
        return (app?.localizedName, app?.bundleIdentifier)
    }

    private static func stringValue(for element: AXUIElement, attribute: CFString) -> String? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return value as? String
    }

    private static func hasAttribute(_ element: AXUIElement, attribute: CFString) -> Bool {
        var value: AnyObject?
        return AXUIElementCopyAttributeValue(element, attribute, &value) == .success
    }

    private static func intValue(for element: AXUIElement, attribute: CFString) -> Int? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        if let number = value as? NSNumber {
            return number.intValue
        }
        return nil
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
