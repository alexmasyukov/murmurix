//
//  AppDelegate.swift
//  Murmurix
//

import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarManager: MenuBarManager!
    private var windowManager: WindowManager!
    private var hotkeyManager: GlobalHotkeyManager!

    private var audioRecorder: AudioRecorder!
    private var transcriptionService: TranscriptionService!
    private var coordinator: RecordingCoordinator!

    private var lastRecordId: UUID?
    private var shouldPasteDirectly = false

    private let historyService = HistoryService.shared
    private let settings = Settings.shared

    // MARK: - App Lifecycle

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        setupServices()
        setupManagers()
        setupHotkeys()

        coordinator.loadModelsIfNeeded()

        NotificationCenter.default.addObserver(
            self, selector: #selector(handleLanguageChange),
            name: .appLanguageDidChange, object: nil
        )
    }

    @MainActor
    func applicationWillTerminate(_ notification: Notification) {
        coordinator.unloadAllModels()
        hotkeyManager.stop()
    }

    // MARK: - Setup

    @MainActor
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // Application menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: L10n.quitMurmurix, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // Edit menu (for Copy/Paste/Undo support in text fields)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: L10n.edit)
        editMenu.addItem(NSMenuItem(title: L10n.undo, action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: L10n.redo, action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: L10n.cut, action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: L10n.copy, action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: L10n.paste, action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: L10n.selectAll, action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    @MainActor
    private func setupServices() {
        audioRecorder = AudioRecorder()
        transcriptionService = TranscriptionService()

        coordinator = RecordingCoordinator(
            audioRecorder: audioRecorder,
            transcriptionService: transcriptionService,
            historyService: historyService,
            settings: settings
        )
        coordinator.delegate = self
    }

    @MainActor
    private func setupManagers() {
        menuBarManager = MenuBarManager(settings: settings)
        menuBarManager.delegate = self
        menuBarManager.setup()

        windowManager = WindowManager()
    }

    private var currentRecordingMode: TranscriptionMode = .local(model: "small")

    @MainActor
    private func setupHotkeys() {
        hotkeyManager = GlobalHotkeyManager()
        hotkeyManager.onToggleLocalRecording = { [weak self] modelName in
            self?.runOnMain { delegate in
                delegate.toggleRecording(mode: .local(model: modelName))
            }
        }
        hotkeyManager.onToggleCloudRecording = { [weak self] in
            self?.runOnMain { delegate in
                delegate.toggleRecording(mode: .openai)
            }
        }
        hotkeyManager.onToggleGeminiRecording = { [weak self] in
            self?.runOnMain { delegate in
                delegate.toggleRecording(mode: .gemini)
            }
        }
        hotkeyManager.onCancelRecording = { [weak self] in
            self?.runOnMain { delegate in
                delegate.cancelRecording()
            }
        }
        hotkeyManager.start()
    }

    private func runOnMain(_ action: @escaping @MainActor (AppDelegate) -> Void) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            action(self)
        }
    }

    @MainActor
    @objc private func handleLanguageChange() {
        setupMainMenu()
        menuBarManager.rebuildMenu()
    }

    // MARK: - Recording Actions

    @MainActor
    private func toggleRecording(mode: TranscriptionMode) {
        if coordinator.state == .idle {
            shouldPasteDirectly = TextPaster.isTextFieldFocused()
            currentRecordingMode = mode
        }
        coordinator.toggleRecording(mode: currentRecordingMode)
    }

    @MainActor
    private func cancelRecording() {
        coordinator.cancelRecording()
        hotkeyManager.isRecording = false
        windowManager.dismissRecordingWindow()
    }

    @MainActor
    private func dismissRecordingUI() {
        windowManager.dismissRecordingWindow()
        shouldPasteDirectly = false
    }
}

// MARK: - MenuBarManagerDelegate

@MainActor
extension AppDelegate: MenuBarManagerDelegate {
    func menuBarDidRequestToggleLocalRecording(model: String) {
        toggleRecording(mode: .local(model: model))
    }

    func menuBarDidRequestToggleCloudRecording() {
        toggleRecording(mode: .openai)
    }

    func menuBarDidRequestToggleGeminiRecording() {
        toggleRecording(mode: .gemini)
    }

    func menuBarDidRequestOpenHistory() {
        windowManager.showHistoryWindow()
    }

    func menuBarDidRequestOpenSettings() {
        windowManager.showSettingsWindow(
            loadedModels: Set(WhisperKitService.shared.loadedModels),
            onModelToggle: { [weak self] model, enabled in
                self?.coordinator.setModelLoaded(enabled, model: model)
            },
            onLocalHotkeysChanged: { [weak self] hotkeys in
                self?.hotkeyManager.updateLocalModelHotkeys(hotkeys)
                self?.menuBarManager.updateLocalModelMenuItems(hotkeys: hotkeys)
            },
            onCloudHotkeysChanged: { [weak self] toggleCloud, toggleGemini, cancel in
                self?.hotkeyManager.updateCloudHotkeys(toggleCloud: toggleCloud, toggleGemini: toggleGemini, cancel: cancel)
                self?.menuBarManager.updateHotkeyDisplay()
            },
            onWindowOpen: { [weak self] in
                self?.hotkeyManager.pause()
            },
            onWindowClose: { [weak self] in
                self?.hotkeyManager.resume()
            }
        )
    }

    func menuBarDidRequestQuit() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - RecordingCoordinatorDelegate

@MainActor
extension AppDelegate: RecordingCoordinatorDelegate {
    func recordingDidStart() {
        hotkeyManager.isRecording = true
        windowManager.showRecordingWindow(
            audioRecorder: audioRecorder,
            onStop: { [weak self] in
                guard let self = self else { return }
                self.coordinator.toggleRecording(mode: self.currentRecordingMode)
            },
            onCancelTranscription: { [weak self] in
                self?.coordinator.cancelTranscription()
            }
        )
    }

    func recordingDidStop() {
        hotkeyManager.isRecording = false
    }

    func transcriptionDidStart() {
        windowManager.showTranscribing()
    }

    func recordingDidStopWithoutVoice() {
        dismissRecordingUI()
    }

    func transcriptionDidComplete(text: String, duration: TimeInterval, recordId: UUID) {
        let pasteDirectly = shouldPasteDirectly
        dismissRecordingUI()
        lastRecordId = recordId

        if pasteDirectly {
            TextPaster.paste(text)
        } else {
            windowManager.showResultWindow(
                text: text,
                duration: duration,
                onDelete: { [weak self] in
                    guard let self = self, let recordId = self.lastRecordId else { return }
                    self.historyService.delete(id: recordId)
                    self.lastRecordId = nil
                }
            )
        }
    }

    func transcriptionDidFail(error: Error) {
        dismissRecordingUI()
        windowManager.showResultWindow(
            text: L10n.error(error.localizedDescription),
            duration: 0,
            onDelete: {}
        )
    }

    func transcriptionDidCancel() {
        dismissRecordingUI()
    }
}
