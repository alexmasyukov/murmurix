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

    private var recordingController: RecordingWindowController?
    private var resultController: ResultWindowController?
    private var settingsController: SettingsWindowController?
    private var historyController: HistoryWindowController?

    private var recordingStartTime: Date?
    private var lastRecordId: UUID?
    private let historyService = HistoryService.shared

    enum AppState {
        case idle
        case recording
        case transcribing
    }

    private var state: AppState = .idle

    private var keepDaemonRunning: Bool {
        UserDefaults.standard.bool(forKey: "keepDaemonRunning")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set default value for daemon
        if UserDefaults.standard.object(forKey: "keepDaemonRunning") == nil {
            UserDefaults.standard.set(true, forKey: "keepDaemonRunning")
        }

        setupMenuBar()
        setupServices()
        setupHotkeys()

        // Start daemon if enabled
        if keepDaemonRunning {
            transcriptionService.startDaemon()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        transcriptionService.stopDaemon()
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
        let hotkey = HotkeySettings.loadToggleHotkey()

        // Convert keyCode to character
        if let keyString = Hotkey.keyCodeToName(hotkey.keyCode)?.lowercased() {
            menuItem.keyEquivalent = keyString
        }

        // Convert Carbon modifiers to NSEvent modifiers
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
        switch state {
        case .idle:
            startRecording()
        case .recording:
            stopRecording()
        case .transcribing:
            break // Do nothing while transcribing
        }
    }

    private func startRecording() {
        state = .recording
        hotkeyManager.isRecording = true
        recordingStartTime = Date()

        recordingController = RecordingWindowController(
            audioRecorder: audioRecorder,
            onStop: { [weak self] in
                self?.stopRecording()
            }
        )
        recordingController?.showWindow(nil)
        audioRecorder.startRecording()
    }

    private func stopRecording() {
        guard state == .recording else { return }
        state = .transcribing
        hotkeyManager.isRecording = false

        let audioURL = audioRecorder.stopRecording()
        let duration = Date().timeIntervalSince(recordingStartTime ?? Date())
        recordingController?.showTranscribing()

        let service = self.transcriptionService!
        let useDaemon = keepDaemonRunning
        let language = UserDefaults.standard.string(forKey: "language") ?? "ru"

        Task.detached {
            do {
                let text = try await service.transcribe(audioURL: audioURL, useDaemon: useDaemon)
                await MainActor.run {
                    self.recordingController?.close()
                    self.recordingController = nil

                    // Save to history
                    let record = TranscriptionRecord(
                        text: text,
                        language: language,
                        duration: duration
                    )
                    self.historyService.save(record: record)
                    self.lastRecordId = record.id

                    self.showResult(text: text, duration: duration)
                    self.state = .idle

                    // Delete audio file
                    try? FileManager.default.removeItem(at: audioURL)
                }
            } catch {
                await MainActor.run {
                    self.recordingController?.close()
                    self.recordingController = nil
                    self.showResult(text: "Error: \(error.localizedDescription)", duration: 0)
                    self.state = .idle

                    // Delete audio file even on error
                    try? FileManager.default.removeItem(at: audioURL)
                }
            }
        }
    }

    private func cancelRecording() {
        guard state == .recording else { return }

        hotkeyManager.isRecording = false
        let audioURL = audioRecorder.stopRecording()
        try? FileManager.default.removeItem(at: audioURL) // Delete cancelled recording
        recordingController?.close()
        recordingController = nil
        state = .idle
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
                    guard let self = self else { return }
                    if enabled {
                        self.transcriptionService.startDaemon()
                    } else {
                        self.transcriptionService.stopDaemon()
                    }
                },
                onHotkeysChanged: { [weak self] toggle, cancel in
                    self?.hotkeyManager.updateHotkeys(toggle: toggle, cancel: cancel)
                    self?.updateMenuHotkey()
                }
            )
        } else {
            // Update daemon status when reopening settings
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

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
}
