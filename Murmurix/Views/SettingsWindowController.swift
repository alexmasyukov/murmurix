//
//  SettingsWindowController.swift
//  Murmurix
//

import Cocoa
import SwiftUI

class ModelStatusModel: ObservableObject {
    @Published var loadedModels: Set<String> = []
}

@MainActor
class SettingsWindowController: NSWindowController, NSWindowDelegate {
    var onModelToggle: ((String, Bool) -> Void)?
    var onLocalHotkeysChanged: (([String: Hotkey]) -> Void)?
    var onCloudHotkeysChanged: ((Hotkey?, Hotkey?, Hotkey?) -> Void)?
    var onWindowOpen: (() -> Void)?
    var onWindowClose: (() -> Void)?

    private let modelStatus = ModelStatusModel()
    private let modelStatusUpdateDelay: TimeInterval = 1
    private var languageObserver: NSObjectProtocol?
    private var modelStatusUpdateTasks: [String: Task<Void, Never>] = [:]

    convenience init(
        settings: SettingsStorageProtocol,
        loadedModels: Set<String>,
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
        self.modelStatus.loadedModels = loadedModels
        window.delegate = self

        let settingsView = SettingsView(
            settings: settings,
            loadedModels: Binding(
                get: { [weak self] in self?.modelStatus.loadedModels ?? [] },
                set: { [weak self] in self?.modelStatus.loadedModels = $0 }
            ),
            onModelToggle: { [weak self] model, enabled in
                onModelToggle(model, enabled)
                self?.scheduleModelStatusUpdate(model: model, enabled: enabled)
            },
            onLocalHotkeysChanged: onLocalHotkeysChanged,
            onCloudHotkeysChanged: onCloudHotkeysChanged
        )
        window.contentView = NSHostingView(rootView: settingsView)
    }

    func updateLoadedModels(_ models: Set<String>) {
        cancelAllModelStatusUpdates()
        modelStatus.loadedModels = models
    }

    private func scheduleModelStatusUpdate(model: String, enabled: Bool) {
        cancelModelStatusUpdate(for: model)
        let delayNanoseconds = UInt64(modelStatusUpdateDelay * 1_000_000_000)

        modelStatusUpdateTasks[model] = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: delayNanoseconds)
            } catch {
                return
            }

            guard let self, !Task.isCancelled else { return }
            defer { self.modelStatusUpdateTasks[model] = nil }

            if enabled {
                self.modelStatus.loadedModels.insert(model)
            } else {
                self.modelStatus.loadedModels.remove(model)
            }
        }
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
        cancelAllModelStatusUpdates()
        stopObservingLanguageChanges()
        onWindowClose?()
    }

    deinit {
        for task in modelStatusUpdateTasks.values {
            task.cancel()
        }
        modelStatusUpdateTasks.removeAll()
        if let languageObserver {
            NotificationCenter.default.removeObserver(languageObserver)
            self.languageObserver = nil
        }
    }

    private func startObservingLanguageChangesIfNeeded() {
        guard languageObserver == nil else { return }
        languageObserver = NotificationCenter.default.addObserver(
            forName: .appLanguageDidChange, object: nil, queue: .main
        ) { [weak window] _ in
            window?.title = L10n.settingsTitle
        }
    }

    private func stopObservingLanguageChanges() {
        guard let languageObserver else { return }
        NotificationCenter.default.removeObserver(languageObserver)
        self.languageObserver = nil
    }

    private func cancelModelStatusUpdate(for model: String) {
        modelStatusUpdateTasks[model]?.cancel()
        modelStatusUpdateTasks[model] = nil
    }

    private func cancelAllModelStatusUpdates() {
        for task in modelStatusUpdateTasks.values {
            task.cancel()
        }
        modelStatusUpdateTasks.removeAll()
    }
}
