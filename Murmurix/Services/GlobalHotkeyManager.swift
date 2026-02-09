//
//  GlobalHotkeyManager.swift
//  Murmurix
//

import Foundation
import Carbon
import AppKit

class GlobalHotkeyManager: HotkeyManagerProtocol {
    var onToggleLocalRecording: ((String) -> Void)?
    var onToggleCloudRecording: (() -> Void)?
    var onToggleGeminiRecording: (() -> Void)?
    var onCancelRecording: (() -> Void)?

    // Only intercept cancel hotkey when recording is active
    var isRecording: Bool = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var localModelHotkeys: [String: Hotkey] = [:]
    private var toggleCloudHotkey: Hotkey?
    private var toggleGeminiHotkey: Hotkey?
    private var cancelHotkey: Hotkey?
    private let settings: SettingsStorageProtocol

    private enum MatchedHotkeyAction {
        case local(modelName: String)
        case cloud
        case gemini
        case cancel
    }

    init(settings: SettingsStorageProtocol = Settings.shared) {
        self.settings = settings
        toggleCloudHotkey = settings.loadToggleCloudHotkey()
        toggleGeminiHotkey = settings.loadToggleGeminiHotkey()
        cancelHotkey = settings.loadCancelHotkey()

        // Load per-model hotkeys
        let modelSettings = settings.loadWhisperModelSettings()
        for (modelName, ms) in modelSettings {
            if let hotkey = ms.hotkey {
                localModelHotkeys[modelName] = hotkey
            }
        }
    }

    func updateLocalModelHotkeys(_ hotkeys: [String: Hotkey]) {
        localModelHotkeys = hotkeys
    }

    func updateCloudHotkeys(toggleCloud: Hotkey?, toggleGemini: Hotkey?, cancel: Hotkey?) {
        toggleCloudHotkey = toggleCloud
        toggleGeminiHotkey = toggleGemini
        cancelHotkey = cancel
    }

    func start() {
        let eventMask = (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            Logger.Hotkey.error("Failed to create event tap. Check Accessibility permissions.")
            requestAccessibilityPermissions()
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        Logger.Hotkey.info("GlobalHotkeyManager started")
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    func pause() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
    }

    func resume() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
        let carbonModifiers = Self.carbonModifiers(from: event.flags)

        if let matchedAction = matchedHotkeyAction(for: keyCode, modifiers: carbonModifiers) {
            dispatchMatchedHotkey(matchedAction)
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    private func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    private static func matches(hotkey: Hotkey?, keyCode: UInt32, modifiers: UInt32) -> Bool {
        guard let hotkey else { return false }
        return hotkey.keyCode == keyCode && hotkey.modifiers == modifiers
    }

    private func matchedHotkeyAction(for keyCode: UInt32, modifiers: UInt32) -> MatchedHotkeyAction? {
        if let modelName = matchingLocalModelName(for: keyCode, modifiers: modifiers) {
            return .local(modelName: modelName)
        }
        if Self.matches(hotkey: toggleCloudHotkey, keyCode: keyCode, modifiers: modifiers) {
            return .cloud
        }
        if Self.matches(hotkey: toggleGeminiHotkey, keyCode: keyCode, modifiers: modifiers) {
            return .gemini
        }
        if isRecording, Self.matches(hotkey: cancelHotkey, keyCode: keyCode, modifiers: modifiers) {
            return .cancel
        }
        return nil
    }

    private func matchingLocalModelName(for keyCode: UInt32, modifiers: UInt32) -> String? {
        localModelHotkeys.first(where: {
            Self.matches(hotkey: $0.value, keyCode: keyCode, modifiers: modifiers)
        })?.key
    }

    private func dispatchMatchedHotkey(_ action: MatchedHotkeyAction) {
        switch action {
        case .local(let modelName):
            onToggleLocalRecording?(modelName)
        case .cloud:
            onToggleCloudRecording?()
        case .gemini:
            onToggleGeminiRecording?()
        case .cancel:
            onCancelRecording?()
        }
    }

    private static func carbonModifiers(from flags: CGEventFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.maskCommand) { result |= UInt32(cmdKey) }
        if flags.contains(.maskAlternate) { result |= UInt32(optionKey) }
        if flags.contains(.maskControl) { result |= UInt32(controlKey) }
        if flags.contains(.maskShift) { result |= UInt32(shiftKey) }
        return result
    }
}
