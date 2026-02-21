//
//  AppDelegate.swift
//  Murmurix
//

import SwiftUI
import AppKit
import UserNotifications

struct AppDependencies {
    let historyService: HistoryServiceProtocol
    let settings: SettingsStorageProtocol
    let makeAudioRecorder: () -> any AudioRecorderProtocol
    let makeTranscriptionService: () -> any TranscriptionServiceProtocol
    let makeGeneralSettingsViewModel: @MainActor () -> GeneralSettingsViewModel

    static func live() -> AppDependencies {
        let settings = Settings(defaults: .standard)
        let historyService = HistoryService.live()
        let promptPolicy = DefaultTranscriptionPromptPolicy()
        let whisperKitService = WhisperKitService()
        let openAIService = OpenAITranscriptionService(
            session: URLSession.shared,
            promptPolicy: promptPolicy
        )
        let geminiService = GeminiTranscriptionService(promptPolicy: promptPolicy)
        return AppDependencies(
            historyService: historyService,
            settings: settings,
            makeAudioRecorder: { AudioRecorder() },
            makeTranscriptionService: {
                TranscriptionService.live(
                    settings: settings,
                    whisperKitService: whisperKitService,
                    openAIService: openAIService,
                    geminiService: geminiService
                )
            },
            makeGeneralSettingsViewModel: {
                GeneralSettingsViewModel.live(
                    settings: settings,
                    whisperKitService: whisperKitService,
                    openAIService: openAIService,
                    geminiService: geminiService
                )
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

    private var lastRecordId: UUID?
    private var shouldPasteDirectly = false
    private var focusContextAtRecordingStart: TextPaster.FocusContext?
    private let focusNotificationToWindowDelayNanoseconds: UInt64 = 250_000_000

    private let historyService: HistoryServiceProtocol
    private let settings: SettingsStorageProtocol
    private let makeAudioRecorder: () -> any AudioRecorderProtocol
    private let makeTranscriptionService: () -> any TranscriptionServiceProtocol
    private let makeGeneralSettingsViewModel: @MainActor () -> GeneralSettingsViewModel

    init(dependencies: AppDependencies) {
        self.historyService = dependencies.historyService
        self.settings = dependencies.settings
        self.makeAudioRecorder = dependencies.makeAudioRecorder
        self.makeTranscriptionService = dependencies.makeTranscriptionService
        self.makeGeneralSettingsViewModel = dependencies.makeGeneralSettingsViewModel
        super.init()
    }

    // MARK: - App Lifecycle

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        setupServices()
        setupManagers()
        setupHotkeys()
        setupNotifications()

        coordinator?.loadModelsIfNeeded()

        AppLanguage.addDidChangeObserver(
            self,
            selector: #selector(handleLanguageDidChangeNotification(_:))
        )
    }

    @MainActor
    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.unloadAllModels()
        hotkeyManager?.stop()
        AppLanguage.removeDidChangeObserver(self)
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
        transcriptionService = makeTranscriptionService()

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

    @MainActor
    private func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        FocusDebugNotifier.registerCategory(center: center)
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

    @objc
    private func handleLanguageDidChangeNotification(_ notification: Notification) {
        runOnMain { delegate in
            delegate.handleLanguageChange()
        }
    }

    // MARK: - Recording Actions

    @MainActor
    private func toggleRecording(mode: TranscriptionMode) {
        guard let coordinator else { return }

        if coordinator.state == .idle {
            let focusContext = TextPaster.focusedContext()
            shouldPasteDirectly = settings.alwaysPasteEnabled || focusContext.isTextInput
            focusContextAtRecordingStart = focusContext
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
        focusContextAtRecordingStart = nil
    }

    @MainActor
    private func handleCompletedTranscription(text: String, duration: TimeInterval, recordId: UUID) {
        let startFocusContext = focusContextAtRecordingStart
            ?? TextPaster.FocusContext(
                status: .noFocusedElement,
                appName: nil,
                role: nil,
                subrole: nil,
                isEditable: nil,
                isTextInput: false
            )
        let shouldPasteFromStart = shouldPasteDirectly
        dismissRecordingUI()
        let endFocusContext = TextPaster.focusedContext()
        let pasteDirectly = settings.alwaysPasteEnabled
            || endFocusContext.isTextInput
            || (endFocusContext.lookupFailed && shouldPasteFromStart)

        let didNotifyFocusDiagnostic = notifyFocusDebugIfNeeded(
            start: startFocusContext,
            end: endFocusContext,
            pasteDirectly: pasteDirectly,
            transcriptionText: text,
            forceWhenPasteIsUnavailable: !pasteDirectly
        )
        lastRecordId = recordId

        if pasteDirectly {
            TextPaster.paste(text)
        } else {
            let onDelete: () -> Void = { [weak self] in
                self?.deleteLastHistoryRecordIfNeeded()
            }
            guard didNotifyFocusDiagnostic else {
                showResultWindow(text: text, duration: duration, onDelete: onDelete)
                return
            }

            Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(nanoseconds: self.focusNotificationToWindowDelayNanoseconds)
                self.showResultWindow(text: text, duration: duration, onDelete: onDelete)
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
            makeGeneralSettingsViewModel: makeGeneralSettingsViewModel,
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

    private func notifyFocusDebugIfNeeded(
        start: TextPaster.FocusContext,
        end: TextPaster.FocusContext,
        pasteDirectly: Bool,
        transcriptionText: String,
        forceWhenPasteIsUnavailable: Bool
    ) -> Bool {
        let shouldNotify = settings.focusDebugNotificationsEnabled || forceWhenPasteIsUnavailable
        guard shouldNotify else { return false }

        let action = pasteDirectly ? "paste" : "show-result-window"
        let alwaysPaste = settings.alwaysPasteEnabled ? "true" : "false"
        let body = "start[\(start.summary)] end[\(end.summary)] action=\(action), alwaysPaste=\(alwaysPaste)"
        Logger.Settings.debug(
            "Focus debug diagnostics: \(body), notificationsEnabled=\(settings.focusDebugNotificationsEnabled), forced=\(forceWhenPasteIsUnavailable)"
        )
        FocusDebugNotifier.notify(
            title: "Murmurix Focus Debug",
            body: body,
            copyText: transcriptionText
        )
        return true
    }

    @MainActor
    private func copyTranscriptionToPasteboard(_ text: String) {
        guard !text.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        Logger.Settings.debug("Focus debug notification action: copied transcription to pasteboard")
    }
}

private enum FocusDebugNotifier {
    static let categoryIdentifier = "murmurix.focus.debug.category"
    static let copyActionIdentifier = "murmurix.focus.debug.copy"
    static let copyTextUserInfoKey = "focusDebugCopyText"

    static func registerCategory(center: UNUserNotificationCenter) {
        let copyAction = UNNotificationAction(
            identifier: copyActionIdentifier,
            title: L10n.copy,
            options: []
        )
        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [copyAction],
            intentIdentifiers: [],
            options: []
        )

        center.getNotificationCategories { existingCategories in
            var updatedCategories = existingCategories
            updatedCategories.update(with: category)
            center.setNotificationCategories(updatedCategories)
        }
    }

    static func notify(title: String, body: String, copyText: String?) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                post(title: title, body: body, copyText: copyText, center: center)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, error in
                    if let error {
                        Logger.Settings.debug("Focus debug notification authorization failed: \(error.localizedDescription)")
                    }
                    guard granted else {
                        Logger.Settings.debug("Focus debug notification authorization denied")
                        return
                    }
                    post(title: title, body: body, copyText: copyText, center: center)
                }
            case .denied:
                Logger.Settings.debug("Focus debug notifications are disabled in system settings")
            @unknown default:
                Logger.Settings.debug("Unknown notification authorization state")
            }
        }
    }

    private static func post(title: String, body: String, copyText: String?, center: UNUserNotificationCenter) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let copyText, !copyText.isEmpty {
            content.categoryIdentifier = categoryIdentifier
            content.userInfo = [copyTextUserInfoKey: copyText]
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "murmurix.focus.debug.\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error {
                Logger.Settings.debug("Failed to post focus debug notification: \(error.localizedDescription)")
            }
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        guard notification.request.identifier.hasPrefix("murmurix.focus.debug.") else {
            completionHandler([])
            return
        }

        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        guard response.actionIdentifier == FocusDebugNotifier.copyActionIdentifier else { return }
        guard let text = response.notification.request.content.userInfo[FocusDebugNotifier.copyTextUserInfoKey] as? String else {
            return
        }

        runOnMain { delegate in
            delegate.copyTranscriptionToPasteboard(text)
        }
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
