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
    func isModelLoaded(name: String) -> Bool
    func loadModel(name: String) async throws
    func unloadModel(name: String) async
    func unloadAllModels() async
    func transcribe(audioURL: URL, mode: TranscriptionMode) async throws -> String
}

// MARK: - Hotkey Management

protocol HotkeyManagerProtocol: AnyObject {
    var onToggleLocalRecording: ((String) -> Void)? { get set }
    var onToggleCloudRecording: (() -> Void)? { get set }
    var onToggleGeminiRecording: (() -> Void)? { get set }
    var onCancelRecording: (() -> Void)? { get set }

    func start()
    func stop()
    func updateLocalModelHotkeys(_ hotkeys: [String: Hotkey])
    func updateCloudHotkeys(toggleCloud: Hotkey?, toggleGemini: Hotkey?, cancel: Hotkey?)
}

// MARK: - Network

protocol URLSessionProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

// MARK: - Settings Storage

protocol SettingsStorageProtocol: AnyObject {
    var language: String { get set }
    var appLanguage: String { get set }
    var openaiApiKey: String { get set }
    var openaiTranscriptionModel: String { get set }
    var geminiApiKey: String { get set }
    var geminiModel: String { get set }

    func loadWhisperModelSettings() -> [String: WhisperModelSettings]
    func saveWhisperModelSettings(_ settings: [String: WhisperModelSettings])
    func loadToggleCloudHotkey() -> Hotkey?
    func saveToggleCloudHotkey(_ hotkey: Hotkey?)
    func loadToggleGeminiHotkey() -> Hotkey?
    func saveToggleGeminiHotkey(_ hotkey: Hotkey?)
    func loadCancelHotkey() -> Hotkey?
    func saveCancelHotkey(_ hotkey: Hotkey?)
}
