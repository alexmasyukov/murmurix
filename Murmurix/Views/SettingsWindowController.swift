//
//  SettingsWindowController.swift
//  Murmurix
//

import Cocoa
import SwiftUI

class ModelStatusModel: ObservableObject {
    @Published var isLoaded: Bool = false
}

class SettingsWindowController: NSWindowController, NSWindowDelegate {
    var onModelToggle: ((Bool) -> Void)?
    var onHotkeysChanged: ((Hotkey, Hotkey, Hotkey, Hotkey) -> Void)?
    var onModelChanged: (() -> Void)?
    var onWindowOpen: (() -> Void)?
    var onWindowClose: (() -> Void)?

    private let modelStatus = ModelStatusModel()

    convenience init(
        isModelLoaded: Bool,
        onModelToggle: @escaping (Bool) -> Void,
        onHotkeysChanged: @escaping (Hotkey, Hotkey, Hotkey, Hotkey) -> Void,
        onModelChanged: @escaping () -> Void = {},
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
        self.onModelToggle = onModelToggle
        self.onHotkeysChanged = onHotkeysChanged
        self.onModelChanged = onModelChanged
        self.onWindowOpen = onWindowOpen
        self.onWindowClose = onWindowClose
        self.modelStatus.isLoaded = isModelLoaded
        window.delegate = self

        let settingsView = SettingsView(
            isModelLoaded: Binding(
                get: { [weak self] in self?.modelStatus.isLoaded ?? false },
                set: { [weak self] in self?.modelStatus.isLoaded = $0 }
            ),
            onModelToggle: { [weak self] enabled in
                onModelToggle(enabled)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self?.modelStatus.isLoaded = enabled
                }
            },
            onHotkeysChanged: onHotkeysChanged,
            onModelChanged: onModelChanged
        )
        window.contentView = NSHostingView(rootView: settingsView)
    }

    func updateModelStatus(_ isLoaded: Bool) {
        modelStatus.isLoaded = isLoaded
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
