//
//  Settings.swift
//  Murmurix
//

import Foundation

final class Settings: SettingsStorageProtocol {
    static let shared = Settings()

    private let defaults: UserDefaults

    // MARK: - Keys

    private enum Keys {
        static let toggleLocalHotkey = "toggleLocalHotkey"
        static let toggleCloudHotkey = "toggleCloudHotkey"
        static let cancelHotkey = "cancelHotkey"
        static let keepDaemonRunning = "keepDaemonRunning"
        static let language = "language"
        static let whisperModel = "whisperModel"
        static let transcriptionMode = "transcriptionMode"
        static let openaiTranscriptionModel = "openaiTranscriptionModel"
    }

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        registerDefaults()
    }

    private func registerDefaults() {
        if defaults.object(forKey: Keys.keepDaemonRunning) == nil {
            defaults.set(true, forKey: Keys.keepDaemonRunning)
        }
        if defaults.string(forKey: Keys.language) == nil {
            defaults.set("ru", forKey: Keys.language)
        }
    }

    // MARK: - Core Settings

    var keepDaemonRunning: Bool {
        get { defaults.bool(forKey: Keys.keepDaemonRunning) }
        set { defaults.set(newValue, forKey: Keys.keepDaemonRunning) }
    }

    var language: String {
        get { defaults.string(forKey: Keys.language) ?? "ru" }
        set { defaults.set(newValue, forKey: Keys.language) }
    }

    var whisperModel: String {
        get { defaults.string(forKey: Keys.whisperModel) ?? WhisperModel.small.rawValue }
        set { defaults.set(newValue, forKey: Keys.whisperModel) }
    }

    // MARK: - Hotkey Settings

    func loadToggleLocalHotkey() -> Hotkey {
        guard let data = defaults.data(forKey: Keys.toggleLocalHotkey),
              let hotkey = try? JSONDecoder().decode(Hotkey.self, from: data) else {
            return .toggleLocalDefault
        }
        return hotkey
    }

    func saveToggleLocalHotkey(_ hotkey: Hotkey) {
        if let data = try? JSONEncoder().encode(hotkey) {
            defaults.set(data, forKey: Keys.toggleLocalHotkey)
        }
    }

    func loadToggleCloudHotkey() -> Hotkey {
        guard let data = defaults.data(forKey: Keys.toggleCloudHotkey),
              let hotkey = try? JSONDecoder().decode(Hotkey.self, from: data) else {
            return .toggleCloudDefault
        }
        return hotkey
    }

    func saveToggleCloudHotkey(_ hotkey: Hotkey) {
        if let data = try? JSONEncoder().encode(hotkey) {
            defaults.set(data, forKey: Keys.toggleCloudHotkey)
        }
    }

    func loadCancelHotkey() -> Hotkey {
        guard let data = defaults.data(forKey: Keys.cancelHotkey),
              let hotkey = try? JSONDecoder().decode(Hotkey.self, from: data) else {
            return .cancelDefault
        }
        return hotkey
    }

    func saveCancelHotkey(_ hotkey: Hotkey) {
        if let data = try? JSONEncoder().encode(hotkey) {
            defaults.set(data, forKey: Keys.cancelHotkey)
        }
    }

    // MARK: - Transcription Mode Settings

    var transcriptionMode: String {
        get { defaults.string(forKey: Keys.transcriptionMode) ?? "local" }
        set { defaults.set(newValue, forKey: Keys.transcriptionMode) }
    }

    var openaiTranscriptionModel: String {
        get { defaults.string(forKey: Keys.openaiTranscriptionModel) ?? OpenAITranscriptionModel.gpt4oTranscribe.rawValue }
        set { defaults.set(newValue, forKey: Keys.openaiTranscriptionModel) }
    }

    var openaiApiKey: String {
        get { KeychainService.load(key: "openaiApiKey") ?? "" }
        set {
            if newValue.isEmpty {
                KeychainService.delete(key: "openaiApiKey")
            } else {
                KeychainService.save(key: "openaiApiKey", value: newValue)
            }
        }
    }
}
