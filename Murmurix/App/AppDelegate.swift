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

    private var recordingWindow: NSWindow?
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

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Murmurix")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Start Recording", action: #selector(startRecording), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Stop Recording", action: #selector(stopRecording), keyEquivalent: "s"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private func setupServices() {
        audioRecorder = AudioRecorder()
        transcriptionService = TranscriptionService()
    }

    private func setupHotkeys() {
        hotkeyManager = GlobalHotkeyManager()
        hotkeyManager.onStartRecording = { [weak self] in
            DispatchQueue.main.async {
                self?.startRecording()
            }
        }
        hotkeyManager.onStopRecording = { [weak self] in
            DispatchQueue.main.async {
                self?.stopRecording()
            }
        }
        hotkeyManager.start()
    }

    @objc func startRecording() {
        guard state == .idle else { return }
        state = .recording

        showRecordingWindow()
        audioRecorder.startRecording()
    }

    @objc func stopRecording() {
        guard state == .recording else { return }
        state = .transcribing

        let audioURL = audioRecorder.stopRecording()
        updateRecordingWindowForTranscribing()

        let service = self.transcriptionService!
        let useDaemon = keepDaemonRunning
        Task.detached {
            do {
                let text = try await service.transcribe(audioURL: audioURL, useDaemon: useDaemon)
                await MainActor.run {
                    self.hideRecordingWindow()
                    self.showResult(text: text)
                    self.state = .idle
                }
            } catch {
                await MainActor.run {
                    self.hideRecordingWindow()
                    self.showResult(text: "Error: \(error.localizedDescription)")
                    self.state = .idle
                }
            }
        }
    }

    @objc func openSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController(onDaemonToggle: { [weak self] enabled in
                guard let self = self else { return }
                if enabled {
                    self.transcriptionService.startDaemon()
                } else {
                    self.transcriptionService.stopDaemon()
                }
            })
        }
        settingsController?.showWindow(nil)
    }

    private func showRecordingWindow() {
        let contentView = RecordingView(isTranscribing: false, onStop: { [weak self] in
            self?.stopRecording()
        })

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 140),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: contentView)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.center()
        window.makeKeyAndOrderFront(nil)

        recordingWindow = window
    }

    private func updateRecordingWindowForTranscribing() {
        let contentView = RecordingView(isTranscribing: true, onStop: {})
        recordingWindow?.contentView = NSHostingView(rootView: contentView)
    }

    private func hideRecordingWindow() {
        recordingWindow?.orderOut(nil)
        recordingWindow = nil
    }

    private func showResult(text: String) {
        resultController = ResultWindowController(text: text)
        resultController?.showWindow(nil)
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
}
