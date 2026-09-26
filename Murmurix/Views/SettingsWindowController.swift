//
//  SettingsWindowController.swift
//  Murmurix
//

import Cocoa
import SwiftUI

@MainActor
class SettingsWindowController: NSWindowController, NSWindowDelegate {
    var onModelToggle: ((String, Bool) -> Void)?
    var onLocalHotkeysChanged: (([String: Hotkey]) -> Void)?
    var onCloudHotkeysChanged: ((Hotkey?, Hotkey?, Hotkey?) -> Void)?
    var onWindowOpen: (() -> Void)?
    var onWindowClose: (() -> Void)?

    private var isObservingLanguageChanges = false

    convenience init(
        settings: SettingsStorageProtocol,
        makeGeneralSettingsViewModel: @MainActor () -> GeneralSettingsViewModel,
        onModelToggle: @escaping (String, Bool) -> Void,
        onLocalHotkeysChanged: @escaping ([String: Hotkey]) -> Void,
        onCloudHotkeysChanged: @escaping (Hotkey?, Hotkey?, Hotkey?) -> Void,
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
        window.delegate = self

        // Loaded/loading state per model is observed live by the view model
        // (GeneralSettingsViewModel.startObservingModelMemoryStates) — no snapshot
        // or timer-based guessing here.
        let generalSettingsViewModel = makeGeneralSettingsViewModel()
        let settingsView = SettingsView(
            settings: settings,
            generalSettingsViewModel: generalSettingsViewModel,
            onModelToggle: onModelToggle,
            onLocalHotkeysChanged: onLocalHotkeysChanged,
            onCloudHotkeysChanged: onCloudHotkeysChanged
        )
        window.contentView = NSHostingView(rootView: settingsView)
    }

    override func showWindow(_ sender: Any?) {
        window?.title = L10n.settingsTitle
        startObservingLanguageChangesIfNeeded()
        window?.center()
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onWindowOpen?()
    }

    func windowWillClose(_ notification: Notification) {
        stopObservingLanguageChanges()
        onWindowClose?()
    }

    deinit {
        AppLanguage.removeDidChangeObserver(self)
    }

    private func startObservingLanguageChangesIfNeeded() {
        guard !isObservingLanguageChanges else { return }
        AppLanguage.addDidChangeObserver(
            self,
            selector: #selector(handleLanguageDidChangeNotification(_:))
        )
        isObservingLanguageChanges = true
    }

    private func stopObservingLanguageChanges() {
        guard isObservingLanguageChanges else { return }
        AppLanguage.removeDidChangeObserver(self)
        isObservingLanguageChanges = false
    }

    @objc
    private func handleLanguageDidChangeNotification(_ notification: Notification) {
        window?.title = L10n.settingsTitle
    }
}
