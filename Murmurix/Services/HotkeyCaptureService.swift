//
//  HotkeyCaptureService.swift
//  Murmurix
//

import AppKit
import Carbon
import Foundation

protocol HotkeyEventMonitorManaging {
    func addLocalKeyDownMonitor(handler: @escaping (NSEvent) -> NSEvent?) -> Any?
    func addGlobalKeyDownMonitor(handler: @escaping (NSEvent) -> Void) -> Any?
    func removeMonitor(_ monitor: Any)
}

struct NSEventMonitorManager: HotkeyEventMonitorManaging {
    func addLocalKeyDownMonitor(handler: @escaping (NSEvent) -> NSEvent?) -> Any? {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: handler)
    }

    func addGlobalKeyDownMonitor(handler: @escaping (NSEvent) -> Void) -> Any? {
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: handler)
    }

    func removeMonitor(_ monitor: Any) {
        NSEvent.removeMonitor(monitor)
    }
}

final class HotkeyCaptureService {
    private let monitorManager: HotkeyEventMonitorManaging
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var onHotkeyCaptured: ((Hotkey) -> Void)?

    private(set) var isCapturing = false

    static func live() -> HotkeyCaptureService {
        HotkeyCaptureService(monitorManager: NSEventMonitorManager())
    }

    init(monitorManager: HotkeyEventMonitorManaging) {
        self.monitorManager = monitorManager
    }

    func startCapturing(onHotkeyCaptured: @escaping (Hotkey) -> Void) {
        guard !isCapturing else { return }
        isCapturing = true
        self.onHotkeyCaptured = onHotkeyCaptured

        localMonitor = monitorManager.addLocalKeyDownMonitor { [weak self] event in
            Task { @MainActor [weak self] in
                self?.capture(event)
            }
            return nil
        }

        globalMonitor = monitorManager.addGlobalKeyDownMonitor { [weak self] event in
            Task { @MainActor [weak self] in
                self?.capture(event)
            }
        }
    }

    func stopCapturing() {
        isCapturing = false
        onHotkeyCaptured = nil
        removeMonitorIfNeeded(&localMonitor)
        removeMonitorIfNeeded(&globalMonitor)
    }

    private func removeMonitorIfNeeded(_ monitor: inout Any?) {
        guard let activeMonitor = monitor else { return }
        monitorManager.removeMonitor(activeMonitor)
        monitor = nil
    }

    private func capture(_ event: NSEvent) {
        guard isCapturing else { return }
        let keyCode = UInt32(event.keyCode)
        let modifiers = carbonModifiers(from: event.modifierFlags)
        let hotkey = Hotkey(keyCode: keyCode, modifiers: modifiers)
        onHotkeyCaptured?(hotkey)
        stopCapturing()
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }
}
