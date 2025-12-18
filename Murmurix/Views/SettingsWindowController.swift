//
//  SettingsWindowController.swift
//  Murmurix
//

import Cocoa
import SwiftUI

class DaemonStatusModel: ObservableObject {
    @Published var isRunning: Bool = false
}

class SettingsWindowController: NSWindowController, NSWindowDelegate {
    var onDaemonToggle: ((Bool) -> Void)?
    var onHotkeysChanged: ((Hotkey, Hotkey) -> Void)?
    var onWindowOpen: (() -> Void)?
    var onWindowClose: (() -> Void)?

    private let daemonStatus = DaemonStatusModel()

    convenience init(
        isDaemonRunning: Bool,
        onDaemonToggle: @escaping (Bool) -> Void,
        onHotkeysChanged: @escaping (Hotkey, Hotkey) -> Void,
        onWindowOpen: @escaping () -> Void = {},
        onWindowClose: @escaping () -> Void = {}
    ) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 420),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 480, height: 380)
        window.title = "Settings"

        self.init(window: window)
        self.onDaemonToggle = onDaemonToggle
        self.onHotkeysChanged = onHotkeysChanged
        self.onWindowOpen = onWindowOpen
        self.onWindowClose = onWindowClose
        self.daemonStatus.isRunning = isDaemonRunning
        window.delegate = self

        let settingsView = SettingsView(
            isDaemonRunning: Binding(
                get: { [weak self] in self?.daemonStatus.isRunning ?? false },
                set: { [weak self] in self?.daemonStatus.isRunning = $0 }
            ),
            onDaemonToggle: { [weak self] enabled in
                onDaemonToggle(enabled)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self?.daemonStatus.isRunning = enabled
                }
            },
            onHotkeysChanged: onHotkeysChanged
        )
        window.contentView = NSHostingView(rootView: settingsView)
    }

    func updateDaemonStatus(_ isRunning: Bool) {
        daemonStatus.isRunning = isRunning
    }

    override func showWindow(_ sender: Any?) {
        window?.center()
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onWindowOpen?()
    }

    func windowWillClose(_ notification: Notification) {
        onWindowClose?()
    }
}
