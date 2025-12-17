//
//  AppDelegate.swift
//  Murmurix
//

import SwiftUI
import AppKit
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotkeyManager: GlobalHotkeyManager!
    private var audioRecorder: AudioRecorder!
    private var transcriptionService: TranscriptionService!
    private var coordinator: RecordingCoordinator!

    private var recordingController: RecordingWindowController?
    private var resultController: ResultWindowController?
    private var settingsController: SettingsWindowController?
    private var historyController: HistoryWindowController?

    private var lastRecordId: UUID?
    private var shouldPasteDirectly = false  // True if hotkey was triggered from a text field
    private let historyService = HistoryService.shared
    private let settings = Settings.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupServices()
        setupCoordinator()
        setupHotkeys()

        coordinator.startDaemonIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator.stopDaemon()
        hotkeyManager.stop()
    }

    private var toggleMenuItem: NSMenuItem?

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Murmurix")
        }

        let menu = NSMenu()

        toggleMenuItem = NSMenuItem(title: "Toggle Recording", action: #selector(toggleRecording), keyEquivalent: "")
        applyHotkeyToMenuItem(toggleMenuItem!)
        menu.addItem(toggleMenuItem!)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "History...", action: #selector(openHistory), keyEquivalent: "h"))
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    func updateMenuHotkey() {
        if let menuItem = toggleMenuItem {
            applyHotkeyToMenuItem(menuItem)
        }
    }

    private func applyHotkeyToMenuItem(_ menuItem: NSMenuItem) {
        let hotkey = settings.loadToggleHotkey()

        if let keyString = Hotkey.keyCodeToName(hotkey.keyCode)?.lowercased() {
            menuItem.keyEquivalent = keyString
        }

        var modifiers: NSEvent.ModifierFlags = []
        if hotkey.modifiers & UInt32(cmdKey) != 0 { modifiers.insert(.command) }
        if hotkey.modifiers & UInt32(optionKey) != 0 { modifiers.insert(.option) }
        if hotkey.modifiers & UInt32(controlKey) != 0 { modifiers.insert(.control) }
        if hotkey.modifiers & UInt32(shiftKey) != 0 { modifiers.insert(.shift) }
        menuItem.keyEquivalentModifierMask = modifiers
    }

    private func setupServices() {
        audioRecorder = AudioRecorder()
        transcriptionService = TranscriptionService()
    }

    private func setupCoordinator() {
        coordinator = RecordingCoordinator(
            audioRecorder: audioRecorder,
            transcriptionService: transcriptionService,
            historyService: historyService,
            settings: settings
        )
        coordinator.delegate = self
    }

    private func setupHotkeys() {
        hotkeyManager = GlobalHotkeyManager()
        hotkeyManager.onToggleRecording = { [weak self] in
            DispatchQueue.main.async {
                self?.toggleRecording()
            }
        }
        hotkeyManager.onCancelRecording = { [weak self] in
            DispatchQueue.main.async {
                self?.cancelRecording()
            }
        }
        hotkeyManager.start()
    }

    @objc func toggleRecording() {
        // Check if we're starting a new recording (not stopping)
        if coordinator.state == .idle {
            // Check if hotkey was triggered from a text field BEFORE recording starts
            shouldPasteDirectly = TextPaster.isTextFieldFocused()
        }
        coordinator.toggleRecording()
    }

    private func cancelRecording() {
        coordinator.cancelRecording()
        hotkeyManager.isRecording = false
        recordingController?.close()
        recordingController = nil
    }

    @objc func openHistory() {
        if historyController == nil {
            historyController = HistoryWindowController()
        }
        historyController?.showWindow(nil)
    }

    @objc func openSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController(
                isDaemonRunning: transcriptionService.isDaemonRunning,
                onDaemonToggle: { [weak self] enabled in
                    self?.coordinator.setDaemonEnabled(enabled)
                },
                onHotkeysChanged: { [weak self] toggle, cancel in
                    self?.hotkeyManager.updateHotkeys(toggle: toggle, cancel: cancel)
                    self?.updateMenuHotkey()
                }
            )
        } else {
            settingsController?.updateDaemonStatus(transcriptionService.isDaemonRunning)
        }
        settingsController?.showWindow(nil)
    }

    private func showResult(text: String, duration: TimeInterval) {
        resultController = ResultWindowController(
            text: text,
            duration: duration,
            onDelete: { [weak self] in
                guard let self = self, let recordId = self.lastRecordId else { return }
                self.historyService.delete(id: recordId)
                self.lastRecordId = nil
            }
        )
        resultController?.showWindow(nil)
    }

    private func dismissRecordingUI() {
        recordingController?.close()
        recordingController = nil
        shouldPasteDirectly = false
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - RecordingCoordinatorDelegate

extension AppDelegate: RecordingCoordinatorDelegate {
    func recordingDidStart() {
        hotkeyManager.isRecording = true
        recordingController = RecordingWindowController(
            audioRecorder: audioRecorder,
            onStop: { [weak self] in
                self?.coordinator.toggleRecording()
            },
            onCancelTranscription: { [weak self] in
                self?.coordinator.cancelTranscription()
            }
        )
        recordingController?.showWindow(nil)
    }

    func recordingDidStop() {
        hotkeyManager.isRecording = false
        // Close window if no transcription will happen (no voice detected)
        // transcriptionDidStart will be called if transcription proceeds
    }

    func transcriptionDidStart() {
        recordingController?.showTranscribing()
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
            showResult(text: text, duration: duration)
        }
    }

    func transcriptionDidFail(error: Error) {
        dismissRecordingUI()
        showResult(text: "Error: \(error.localizedDescription)", duration: 0)
    }

    func transcriptionDidCancel() {
        dismissRecordingUI()
    }
}
