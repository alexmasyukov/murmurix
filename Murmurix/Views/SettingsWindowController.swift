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

    private let daemonStatus = DaemonStatusModel()

    convenience init(
        isDaemonRunning: Bool,
        onDaemonToggle: @escaping (Bool) -> Void,
        onHotkeysChanged: @escaping (Hotkey, Hotkey) -> Void
    ) {
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
        self.daemonStatus.isRunning = isDaemonRunning
        window.delegate = self

        let settingsView = SettingsView(
            isDaemonRunning: Binding(
                get: { [weak self] in self?.daemonStatus.isRunning ?? false },
                set: { [weak self] in self?.daemonStatus.isRunning = $0 }
            ),
            onDaemonToggle: { [weak self] enabled in
                onDaemonToggle(enabled)
                // Update status after a short delay to let daemon start/stop
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
        NSApp.activate(ignoringOtherApps: true)
    }
}
