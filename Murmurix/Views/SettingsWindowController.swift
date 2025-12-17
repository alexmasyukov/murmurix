//
//  SettingsWindowController.swift
//  Murmurix
//

import Cocoa
import SwiftUI

class SettingsWindowController: NSWindowController, NSWindowDelegate {
    var onDaemonToggle: ((Bool) -> Void)?

    convenience init(onDaemonToggle: @escaping (Bool) -> Void) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Murmurix Settings"

        self.init(window: window)
        self.onDaemonToggle = onDaemonToggle
        window.delegate = self

        let settingsView = SettingsView(onDaemonToggle: onDaemonToggle)
        window.contentView = NSHostingView(rootView: settingsView)
    }

    override func showWindow(_ sender: Any?) {
        window?.center()
        super.showWindow(sender)
        NSApp.activate(ignoringOtherApps: true)
    }
}
