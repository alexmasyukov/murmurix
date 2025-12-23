//
//  Protocols.swift
//  Murmurix
//

import Foundation

// MARK: - Audio Recording

protocol AudioRecorderProtocol: AnyObject {
    var isRecording: Bool { get }
    var audioLevel: Float { get }
    var hadVoiceActivity: Bool { get }  // True if audio level exceeded threshold during recording

    func startRecording()
    func stopRecording() -> URL
}

// MARK: - Transcription

protocol TranscriptionServiceProtocol: Sendable {
    var isDaemonRunning: Bool { get }

    func startDaemon()
    func stopDaemon()
    func transcribe(audioURL: URL, useDaemon: Bool) async throws -> String
}

// MARK: - Hotkey Management

protocol HotkeyManagerProtocol: AnyObject {
    var onToggleRecording: (() -> Void)? { get set }
    var onToggleRecordingNoAI: (() -> Void)? { get set }
    var onCancelRecording: (() -> Void)? { get set }

    func start()
    func stop()
    func updateHotkeys(toggle: Hotkey, toggleNoAI: Hotkey, cancel: Hotkey)
}

// MARK: - Settings Storage

protocol SettingsStorageProtocol: AnyObject {
    var keepDaemonRunning: Bool { get set }
    var language: String { get set }
    var aiPostProcessingEnabled: Bool { get set }
    var transcriptionMode: String { get set }
    var whisperModel: String { get set }
    var openaiApiKey: String { get set }
    var openaiTranscriptionModel: String { get set }
    var claudeApiKey: String { get set }
    var aiPrompt: String { get set }
    var aiModel: String { get set }

    func loadToggleHotkey() -> Hotkey
    func saveToggleHotkey(_ hotkey: Hotkey)
    func loadToggleNoAIHotkey() -> Hotkey
    func saveToggleNoAIHotkey(_ hotkey: Hotkey)
    func loadCancelHotkey() -> Hotkey
    func saveCancelHotkey(_ hotkey: Hotkey)
}
