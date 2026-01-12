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
    func transcribe(audioURL: URL, useDaemon: Bool, mode: TranscriptionMode) async throws -> String
}

// MARK: - Hotkey Management

protocol HotkeyManagerProtocol: AnyObject {
    var onToggleLocalRecording: (() -> Void)? { get set }
    var onToggleCloudRecording: (() -> Void)? { get set }
    var onToggleGeminiRecording: (() -> Void)? { get set }
    var onCancelRecording: (() -> Void)? { get set }

    func start()
    func stop()
    func updateHotkeys(toggleLocal: Hotkey, toggleCloud: Hotkey, toggleGemini: Hotkey, cancel: Hotkey)
}

// MARK: - Settings Storage

protocol SettingsStorageProtocol: AnyObject {
    var keepDaemonRunning: Bool { get set }
    var language: String { get set }
    var transcriptionMode: String { get set }
    var whisperModel: String { get set }
    var openaiApiKey: String { get set }
    var openaiTranscriptionModel: String { get set }
    var geminiApiKey: String { get set }
    var geminiModel: String { get set }

    func loadToggleLocalHotkey() -> Hotkey
    func saveToggleLocalHotkey(_ hotkey: Hotkey)
    func loadToggleCloudHotkey() -> Hotkey
    func saveToggleCloudHotkey(_ hotkey: Hotkey)
    func loadToggleGeminiHotkey() -> Hotkey
    func saveToggleGeminiHotkey(_ hotkey: Hotkey)
    func loadCancelHotkey() -> Hotkey
    func saveCancelHotkey(_ hotkey: Hotkey)
}
