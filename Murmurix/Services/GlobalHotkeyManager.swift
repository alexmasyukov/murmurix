//
//  GlobalHotkeyManager.swift
//  Murmurix
//

import Foundation
import Carbon
import AppKit

class GlobalHotkeyManager: HotkeyManagerProtocol {
    var onToggleRecording: (() -> Void)?
    var onCancelRecording: (() -> Void)?

    // Only intercept cancel hotkey when recording is active
    var isRecording: Bool = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var toggleHotkey: Hotkey
    private var cancelHotkey: Hotkey

    init() {
        toggleHotkey = HotkeySettings.loadToggleHotkey()
        cancelHotkey = HotkeySettings.loadCancelHotkey()
    }

    func updateHotkeys(toggle: Hotkey, cancel: Hotkey) {
        toggleHotkey = toggle
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
            print("Failed to create event tap. Check Accessibility permissions.")
            requestAccessibilityPermissions()
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        print("GlobalHotkeyManager started")
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

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .keyDown {
            let keyCode = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags

            // Convert CGEventFlags to Carbon modifiers
            var carbonModifiers: UInt32 = 0
            if flags.contains(.maskCommand) { carbonModifiers |= UInt32(cmdKey) }
            if flags.contains(.maskAlternate) { carbonModifiers |= UInt32(optionKey) }
            if flags.contains(.maskControl) { carbonModifiers |= UInt32(controlKey) }
            if flags.contains(.maskShift) { carbonModifiers |= UInt32(shiftKey) }

            // Check toggle hotkey
            if keyCode == toggleHotkey.keyCode && carbonModifiers == toggleHotkey.modifiers {
                onToggleRecording?()
                return nil // consume the event
            }

            // Check cancel hotkey - only when recording
            if isRecording && keyCode == cancelHotkey.keyCode && carbonModifiers == cancelHotkey.modifiers {
                onCancelRecording?()
                return nil // consume the event
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
