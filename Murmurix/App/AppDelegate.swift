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

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        setupServices()
        setupManagers()
        setupHotkeys()

        coordinator.startDaemonIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator.stopDaemon()
        hotkeyManager.stop()
    }

    // MARK: - Setup

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // Application menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Quit Murmurix", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // Edit menu (for Copy/Paste/Undo support in text fields)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

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

    private func setupManagers() {
        menuBarManager = MenuBarManager(settings: settings)
        menuBarManager.delegate = self
        menuBarManager.setup()

        windowManager = WindowManager()
    }

    private func setupHotkeys() {
        hotkeyManager = GlobalHotkeyManager()
        hotkeyManager.onToggleRecording = { [weak self] in
            DispatchQueue.main.async {
                self?.toggleRecording(skipAI: false)
            }
        }
        hotkeyManager.onToggleRecordingNoAI = { [weak self] in
            DispatchQueue.main.async {
                self?.toggleRecording(skipAI: true)
            }
        }
        hotkeyManager.onCancelRecording = { [weak self] in
            DispatchQueue.main.async {
                self?.cancelRecording()
            }
        }
        hotkeyManager.start()
    }

    // MARK: - Recording Actions

    private func toggleRecording(skipAI: Bool = false) {
        if coordinator.state == .idle {
            shouldPasteDirectly = TextPaster.isTextFieldFocused()
        }
        coordinator.toggleRecording(skipAI: skipAI)
    }

    private func cancelRecording() {
        coordinator.cancelRecording()
        hotkeyManager.isRecording = false
        windowManager.dismissRecordingWindow()
    }

    private func dismissRecordingUI() {
        windowManager.dismissRecordingWindow()
        shouldPasteDirectly = false
    }
}

// MARK: - MenuBarManagerDelegate

extension AppDelegate: MenuBarManagerDelegate {
    func menuBarDidRequestToggleRecording() {
        toggleRecording(skipAI: false)
    }

    func menuBarDidRequestToggleRecordingNoAI() {
        toggleRecording(skipAI: true)
    }

    func menuBarDidRequestOpenHistory() {
        windowManager.showHistoryWindow()
    }

    func menuBarDidRequestOpenSettings() {
        windowManager.showSettingsWindow(
            isDaemonRunning: transcriptionService.isDaemonRunning,
            onDaemonToggle: { [weak self] enabled in
                self?.coordinator.setDaemonEnabled(enabled)
            },
            onHotkeysChanged: { [weak self] toggle, toggleNoAI, cancel in
                self?.hotkeyManager.updateHotkeys(toggle: toggle, toggleNoAI: toggleNoAI, cancel: cancel)
                self?.menuBarManager.updateHotkeyDisplay()
            },
            onModelChanged: { [weak self] in
                self?.coordinator.restartDaemon()
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

extension AppDelegate: RecordingCoordinatorDelegate {
    func recordingDidStart() {
        hotkeyManager.isRecording = true
        windowManager.showRecordingWindow(
            audioRecorder: audioRecorder,
            onStop: { [weak self] in
                self?.coordinator.toggleRecording()
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

    func processingDidStart() {
        windowManager.showProcessing()
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
            text: "Error: \(error.localizedDescription)",
            duration: 0,
            onDelete: {}
        )
    }

    func transcriptionDidCancel() {
        dismissRecordingUI()
    }
}
