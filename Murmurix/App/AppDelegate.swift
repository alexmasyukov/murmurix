//
//  AppDelegate.swift
//  Murmurix
//

import SwiftUI
import AppKit

struct AppDependencies {
    let historyService: HistoryServiceProtocol
    let settings: SettingsStorageProtocol
    let makeAudioRecorder: () -> any AudioRecorderProtocol
    let makeTranscriptionService: (SettingsStorageProtocol) -> any TranscriptionServiceProtocol

    static func live() -> AppDependencies {
        AppDependencies(
            historyService: HistoryService.shared,
            settings: Settings.shared,
            makeAudioRecorder: { AudioRecorder() },
            makeTranscriptionService: { settings in
                TranscriptionService.live(settings: settings)
            }
        )
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarManager: MenuBarManager?
    private var windowManager: WindowManager?
    private var hotkeyManager: GlobalHotkeyManager?

    private var audioRecorder: (any AudioRecorderProtocol)?
    private var transcriptionService: (any TranscriptionServiceProtocol)?
    private var coordinator: RecordingCoordinator?
    private var languageObserver: NSObjectProtocol?

    private var lastRecordId: UUID?
    private var shouldPasteDirectly = false

    private let historyService: HistoryServiceProtocol
    private let settings: SettingsStorageProtocol
    private let makeAudioRecorder: () -> any AudioRecorderProtocol
    private let makeTranscriptionService: (SettingsStorageProtocol) -> any TranscriptionServiceProtocol

    init(dependencies: AppDependencies = .live()) {
        self.historyService = dependencies.historyService
        self.settings = dependencies.settings
        self.makeAudioRecorder = dependencies.makeAudioRecorder
        self.makeTranscriptionService = dependencies.makeTranscriptionService
        super.init()
    }

    // MARK: - App Lifecycle

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        setupServices()
        setupManagers()
        setupHotkeys()

        coordinator?.loadModelsIfNeeded()

        languageObserver = NotificationCenter.default.addObserver(
            forName: .appLanguageDidChange,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                guard let appDelegate = NSApp.delegate as? AppDelegate else { return }
                appDelegate.handleLanguageChange()
            }
        }
    }

    @MainActor
    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.unloadAllModels()
        hotkeyManager?.stop()
        if let languageObserver {
            NotificationCenter.default.removeObserver(languageObserver)
            self.languageObserver = nil
        }
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
        audioRecorder = makeAudioRecorder()
        transcriptionService = makeTranscriptionService(settings)

        guard let audioRecorder, let transcriptionService else { return }

        coordinator = RecordingCoordinator(
            audioRecorder: audioRecorder,
            transcriptionService: transcriptionService,
            historyService: historyService,
            settings: settings
        )
        coordinator?.delegate = self
    }

    @MainActor
    private func setupManagers() {
        menuBarManager = MenuBarManager(settings: settings)
        menuBarManager?.delegate = self
        menuBarManager?.setup()

        windowManager = WindowManager(historyService: historyService)
    }

    private var currentRecordingMode: TranscriptionMode = .local(model: "small")

    @MainActor
    private func setupHotkeys() {
        hotkeyManager = GlobalHotkeyManager(settings: settings)
        bindHotkeyHandlers()
        hotkeyManager?.start()
    }

    private func runOnMain(_ action: @escaping @MainActor (AppDelegate) -> Void) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            action(self)
        }
    }

    private func bindHotkeyHandlers() {
        guard let hotkeyManager else { return }

        hotkeyManager.onToggleLocalRecording = { [weak self] modelName in
            self?.toggleRecordingOnMain(.local(model: modelName))
        }
        hotkeyManager.onToggleCloudRecording = { [weak self] in
            self?.toggleRecordingOnMain(.openai)
        }
        hotkeyManager.onToggleGeminiRecording = { [weak self] in
            self?.toggleRecordingOnMain(.gemini)
        }
        hotkeyManager.onCancelRecording = { [weak self] in
            self?.runOnMain { delegate in
                delegate.cancelRecording()
            }
        }
    }

    private func toggleRecordingOnMain(_ mode: TranscriptionMode) {
        runOnMain { delegate in
            delegate.toggleRecording(mode: mode)
        }
    }

    @MainActor
    private func handleLanguageChange() {
        setupMainMenu()
        menuBarManager?.rebuildMenu()
    }

    // MARK: - Recording Actions

    @MainActor
    private func toggleRecording(mode: TranscriptionMode) {
        guard let coordinator else { return }

        if coordinator.state == .idle {
            shouldPasteDirectly = TextPaster.isTextFieldFocused()
            currentRecordingMode = mode
        }
        coordinator.toggleRecording(mode: currentRecordingMode)
    }

    @MainActor
    private func cancelRecording() {
        coordinator?.cancelRecording()
        hotkeyManager?.isRecording = false
        windowManager?.dismissRecordingWindow()
    }

    @MainActor
    private func dismissRecordingUI() {
        windowManager?.dismissRecordingWindow()
        shouldPasteDirectly = false
    }

    @MainActor
    private func handleCompletedTranscription(text: String, duration: TimeInterval, recordId: UUID) {
        let pasteDirectly = shouldPasteDirectly
        dismissRecordingUI()
        lastRecordId = recordId

        if pasteDirectly {
            TextPaster.paste(text)
        } else {
            showResultWindow(text: text, duration: duration) { [weak self] in
                self?.deleteLastHistoryRecordIfNeeded()
            }
        }
    }

    @MainActor
    private func showResultWindow(text: String, duration: TimeInterval, onDelete: @escaping () -> Void = {}) {
        windowManager?.showResultWindow(
            text: text,
            duration: duration,
            onDelete: onDelete
        )
    }

    @MainActor
    private func deleteLastHistoryRecordIfNeeded() {
        guard let recordId = lastRecordId else { return }
        historyService.delete(id: recordId)
        lastRecordId = nil
    }

    @MainActor
    private func showSettingsWindow() {
        guard let transcriptionService else { return }

        windowManager?.showSettingsWindow(
            settings: settings,
            loadedModels: Set(transcriptionService.loadedModelNames()),
            onModelToggle: { [weak self] model, enabled in
                self?.handleModelToggle(model, enabled: enabled)
            },
            onLocalHotkeysChanged: { [weak self] hotkeys in
                self?.handleLocalHotkeysChanged(hotkeys)
            },
            onCloudHotkeysChanged: { [weak self] toggleCloud, toggleGemini, cancel in
                self?.handleCloudHotkeysChanged(toggleCloud: toggleCloud, toggleGemini: toggleGemini, cancel: cancel)
            },
            onWindowOpen: { [weak self] in
                self?.hotkeyManager?.pause()
            },
            onWindowClose: { [weak self] in
                self?.hotkeyManager?.resume()
            }
        )
    }

    @MainActor
    private func handleModelToggle(_ model: String, enabled: Bool) {
        coordinator?.setModelLoaded(enabled, model: model)
    }

    @MainActor
    private func handleLocalHotkeysChanged(_ hotkeys: [String: Hotkey]) {
        hotkeyManager?.updateLocalModelHotkeys(hotkeys)
        menuBarManager?.updateLocalModelMenuItems(hotkeys: hotkeys)
    }

    @MainActor
    private func handleCloudHotkeysChanged(toggleCloud: Hotkey?, toggleGemini: Hotkey?, cancel: Hotkey?) {
        hotkeyManager?.updateCloudHotkeys(toggleCloud: toggleCloud, toggleGemini: toggleGemini, cancel: cancel)
        menuBarManager?.updateHotkeyDisplay()
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
        windowManager?.showHistoryWindow()
    }

    func menuBarDidRequestOpenSettings() {
        showSettingsWindow()
    }

    func menuBarDidRequestQuit() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - RecordingCoordinatorDelegate

@MainActor
extension AppDelegate: RecordingCoordinatorDelegate {
    func recordingDidStart() {
        guard let audioRecorder else { return }

        hotkeyManager?.isRecording = true
        windowManager?.showRecordingWindow(
            audioRecorder: audioRecorder,
            onStop: { [weak self] in
                guard let self else { return }
                self.coordinator?.toggleRecording(mode: self.currentRecordingMode)
            },
            onCancelTranscription: { [weak self] in
                self?.coordinator?.cancelTranscription()
            }
        )
    }

    func recordingDidStop() {
        hotkeyManager?.isRecording = false
    }

    func transcriptionDidStart() {
        windowManager?.showTranscribing()
    }

    func recordingDidStopWithoutVoice() {
        dismissRecordingUI()
    }

    func transcriptionDidComplete(text: String, duration: TimeInterval, recordId: UUID) {
        handleCompletedTranscription(text: text, duration: duration, recordId: recordId)
    }

    func transcriptionDidFail(error: Error) {
        dismissRecordingUI()
        showResultWindow(
            text: L10n.error(error.localizedDescription),
            duration: 0
        )
    }

    func transcriptionDidCancel() {
        dismissRecordingUI()
    }
}
