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

    // Disable hotkey interception while user is recording a new hotkey in settings
    static var isRecordingHotkey: Bool = false

    // Disable hotkey interception while settings window is open
    static var isSettingsWindowActive: Bool = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var localModelHotkeys: [String: Hotkey] = [:]
    private var toggleCloudHotkey: Hotkey?
    private var toggleGeminiHotkey: Hotkey?
    private var cancelHotkey: Hotkey?
    private let settings: SettingsStorageProtocol

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
        // Skip interception while user is recording a new hotkey or settings window is active
        if GlobalHotkeyManager.isRecordingHotkey || GlobalHotkeyManager.isSettingsWindowActive {
            return Unmanaged.passUnretained(event)
        }

        if type == .keyDown {
            let keyCode = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags

            // Convert CGEventFlags to Carbon modifiers
            var carbonModifiers: UInt32 = 0
            if flags.contains(.maskCommand) { carbonModifiers |= UInt32(cmdKey) }
            if flags.contains(.maskAlternate) { carbonModifiers |= UInt32(optionKey) }
            if flags.contains(.maskControl) { carbonModifiers |= UInt32(controlKey) }
            if flags.contains(.maskShift) { carbonModifiers |= UInt32(shiftKey) }

            // Check local model hotkeys
            for (modelName, hotkey) in localModelHotkeys {
                if keyCode == hotkey.keyCode && carbonModifiers == hotkey.modifiers {
                    onToggleLocalRecording?(modelName)
                    return nil
                }
            }

            // Check toggle cloud (OpenAI) hotkey
            if let hk = toggleCloudHotkey, keyCode == hk.keyCode && carbonModifiers == hk.modifiers {
                onToggleCloudRecording?()
                return nil
            }

            // Check toggle Gemini hotkey
            if let hk = toggleGeminiHotkey, keyCode == hk.keyCode && carbonModifiers == hk.modifiers {
                onToggleGeminiRecording?()
                return nil
            }

            // Check cancel hotkey - only when recording
            if let hk = cancelHotkey, isRecording && keyCode == hk.keyCode && carbonModifiers == hk.modifiers {
                onCancelRecording?()
                return nil
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
