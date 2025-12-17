//
//  SettingsWindowController.swift
//  Murmurix
//

import Cocoa
import SwiftUI

class SettingsWindowController: NSWindowController, NSWindowDelegate {
    var onDaemonToggle: ((Bool) -> Void)?
    var onHotkeysChanged: ((Hotkey, Hotkey) -> Void)?

    convenience init(onDaemonToggle: @escaping (Bool) -> Void, onHotkeysChanged: @escaping (Hotkey, Hotkey) -> Void) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 340),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Murmurix Settings"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.appearance = NSAppearance(named: .darkAqua)

        self.init(window: window)
        self.onDaemonToggle = onDaemonToggle
        self.onHotkeysChanged = onHotkeysChanged
        window.delegate = self

        let settingsView = SettingsView(
            onDaemonToggle: onDaemonToggle,
            onHotkeysChanged: onHotkeysChanged
        )
        window.contentView = NSHostingView(rootView: settingsView)
    }

    override func showWindow(_ sender: Any?) {
        window?.center()
        super.showWindow(sender)
        NSApp.activate(ignoringOtherApps: true)
    }
}
