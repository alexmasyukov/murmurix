//
//  AppDelegate.swift
//  Murmurix
//

import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotkeyManager: GlobalHotkeyManager!
    private var audioRecorder: AudioRecorder!
    private var transcriptionService: TranscriptionService!

    private var recordingController: RecordingWindowController?
    private var resultController: ResultWindowController?
    private var settingsController: SettingsWindowController?

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

        let hotkey = HotkeySettings.loadToggleHotkey()
        let hotkeyString = hotkey.displayParts.joined()
        toggleMenuItem = NSMenuItem(title: "Toggle Recording  \(hotkeyString)", action: #selector(toggleRecording), keyEquivalent: "")
        menu.addItem(toggleMenuItem!)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    func updateMenuHotkey() {
        let hotkey = HotkeySettings.loadToggleHotkey()
        let hotkeyString = hotkey.displayParts.joined()
        toggleMenuItem?.title = "Toggle Recording  \(hotkeyString)"
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

        let audioURL = audioRecorder.stopRecording()
        recordingController?.showTranscribing()

        let service = self.transcriptionService!
        let useDaemon = keepDaemonRunning
        Task.detached {
            do {
                let text = try await service.transcribe(audioURL: audioURL, useDaemon: useDaemon)
                await MainActor.run {
                    self.recordingController?.close()
                    self.recordingController = nil
                    self.showResult(text: text)
                    self.state = .idle
                }
            } catch {
                await MainActor.run {
                    self.recordingController?.close()
                    self.recordingController = nil
                    self.showResult(text: "Error: \(error.localizedDescription)")
                    self.state = .idle
                }
            }
        }
    }

    private func cancelRecording() {
        guard state == .recording else { return }

        _ = audioRecorder.stopRecording()
        recordingController?.close()
        recordingController = nil
        state = .idle
    }

    @objc func openSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController(
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
        }
        settingsController?.showWindow(nil)
    }

    private func showResult(text: String) {
        resultController = ResultWindowController(text: text)
        resultController?.showWindow(nil)
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
}
