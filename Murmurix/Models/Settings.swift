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
        static let toggleGeminiHotkey = "toggleGeminiHotkey"
        static let cancelHotkey = "cancelHotkey"
        static let keepModelLoaded = "keepModelLoaded"
        static let language = "language"
        static let whisperModel = "whisperModel"
        static let transcriptionMode = "transcriptionMode"
        static let openaiTranscriptionModel = "openaiTranscriptionModel"
        static let geminiModel = "geminiModel"
    }

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        registerDefaults()
    }

    private func registerDefaults() {
        // Migrate old key name
        if defaults.object(forKey: "keepModelLoaded") == nil,
           let oldValue = defaults.object(forKey: "keepDaemonRunning") as? Bool {
            defaults.set(oldValue, forKey: "keepModelLoaded")
            defaults.removeObject(forKey: "keepDaemonRunning")
        }

        if defaults.object(forKey: Keys.keepModelLoaded) == nil {
            defaults.set(true, forKey: Keys.keepModelLoaded)
        }
        if defaults.string(forKey: Keys.language) == nil {
            defaults.set(Defaults.language, forKey: Keys.language)
        }
    }

    // MARK: - Core Settings

    var keepModelLoaded: Bool {
        get { defaults.bool(forKey: Keys.keepModelLoaded) }
        set { defaults.set(newValue, forKey: Keys.keepModelLoaded) }
    }

    var language: String {
        get { defaults.string(forKey: Keys.language) ?? Defaults.language }
        set { defaults.set(newValue, forKey: Keys.language) }
    }

    var whisperModel: String {
        get { defaults.string(forKey: Keys.whisperModel) ?? WhisperModel.small.rawValue }
        set { defaults.set(newValue, forKey: Keys.whisperModel) }
    }

    // MARK: - Hotkey Settings

    // Private helpers for DRY
    private func loadHotkey(key: String, defaultHotkey: Hotkey) -> Hotkey {
        guard let data = defaults.data(forKey: key),
              let hotkey = try? JSONDecoder().decode(Hotkey.self, from: data) else {
            return defaultHotkey
        }
        return hotkey
    }

    private func saveHotkey(key: String, hotkey: Hotkey) {
        if let data = try? JSONEncoder().encode(hotkey) {
            defaults.set(data, forKey: key)
        }
    }

    func loadToggleLocalHotkey() -> Hotkey {
        loadHotkey(key: Keys.toggleLocalHotkey, defaultHotkey: .toggleLocalDefault)
    }

    func saveToggleLocalHotkey(_ hotkey: Hotkey) {
        saveHotkey(key: Keys.toggleLocalHotkey, hotkey: hotkey)
    }

    func loadToggleCloudHotkey() -> Hotkey {
        loadHotkey(key: Keys.toggleCloudHotkey, defaultHotkey: .toggleCloudDefault)
    }

    func saveToggleCloudHotkey(_ hotkey: Hotkey) {
        saveHotkey(key: Keys.toggleCloudHotkey, hotkey: hotkey)
    }

    func loadCancelHotkey() -> Hotkey {
        loadHotkey(key: Keys.cancelHotkey, defaultHotkey: .cancelDefault)
    }

    func saveCancelHotkey(_ hotkey: Hotkey) {
        saveHotkey(key: Keys.cancelHotkey, hotkey: hotkey)
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
        get { KeychainService.load(KeychainKey.openaiApiKey) ?? "" }
        set {
            if newValue.isEmpty {
                KeychainService.delete(KeychainKey.openaiApiKey)
            } else {
                KeychainService.save(KeychainKey.openaiApiKey, value: newValue)
            }
        }
    }

    // MARK: - Gemini Settings

    var geminiApiKey: String {
        get { KeychainService.load(KeychainKey.geminiApiKey) ?? "" }
        set {
            if newValue.isEmpty {
                KeychainService.delete(KeychainKey.geminiApiKey)
            } else {
                KeychainService.save(KeychainKey.geminiApiKey, value: newValue)
            }
        }
    }

    var geminiModel: String {
        get { defaults.string(forKey: Keys.geminiModel) ?? GeminiTranscriptionModel.flash2.rawValue }
        set { defaults.set(newValue, forKey: Keys.geminiModel) }
    }

    func loadToggleGeminiHotkey() -> Hotkey {
        loadHotkey(key: Keys.toggleGeminiHotkey, defaultHotkey: .toggleGeminiDefault)
    }

    func saveToggleGeminiHotkey(_ hotkey: Hotkey) {
        saveHotkey(key: Keys.toggleGeminiHotkey, hotkey: hotkey)
    }
}
