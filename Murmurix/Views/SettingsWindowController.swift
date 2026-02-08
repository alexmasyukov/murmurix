//
//  SettingsWindowController.swift
//  Murmurix
//

import Cocoa
import SwiftUI

class ModelStatusModel: ObservableObject {
    @Published var loadedModels: Set<String> = []
}

class SettingsWindowController: NSWindowController, NSWindowDelegate {
    var onModelToggle: ((String, Bool) -> Void)?
    var onLocalHotkeysChanged: (([String: Hotkey]) -> Void)?
    var onCloudHotkeysChanged: ((Hotkey, Hotkey, Hotkey) -> Void)?
    var onWindowOpen: (() -> Void)?
    var onWindowClose: (() -> Void)?

    private let modelStatus = ModelStatusModel()

    convenience init(
        loadedModels: Set<String>,
        onModelToggle: @escaping (String, Bool) -> Void,
        onLocalHotkeysChanged: @escaping ([String: Hotkey]) -> Void,
        onCloudHotkeysChanged: @escaping (Hotkey, Hotkey, Hotkey) -> Void,
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
        window.title = L10n.settingsTitle

        self.init(window: window)
        self.onModelToggle = onModelToggle
        self.onLocalHotkeysChanged = onLocalHotkeysChanged
        self.onCloudHotkeysChanged = onCloudHotkeysChanged
        self.onWindowOpen = onWindowOpen
        self.onWindowClose = onWindowClose
        self.modelStatus.loadedModels = loadedModels
        window.delegate = self

        NotificationCenter.default.addObserver(
            forName: .appLanguageDidChange, object: nil, queue: .main
        ) { [weak window] _ in
            window?.title = L10n.settingsTitle
        }

        let settingsView = SettingsView(
            loadedModels: Binding(
                get: { [weak self] in self?.modelStatus.loadedModels ?? [] },
                set: { [weak self] in self?.modelStatus.loadedModels = $0 }
            ),
            onModelToggle: { [weak self] model, enabled in
                onModelToggle(model, enabled)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    if enabled {
                        self?.modelStatus.loadedModels.insert(model)
                    } else {
                        self?.modelStatus.loadedModels.remove(model)
                    }
                }
            },
            onLocalHotkeysChanged: onLocalHotkeysChanged,
            onCloudHotkeysChanged: onCloudHotkeysChanged
        )
        window.contentView = NSHostingView(rootView: settingsView)
    }

    func updateLoadedModels(_ models: Set<String>) {
        modelStatus.loadedModels = models
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
