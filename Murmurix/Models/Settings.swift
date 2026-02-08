//
//  Settings.swift
//  Murmurix
//

import Foundation

struct WhisperModelSettings: Codable, Equatable {
    var hotkey: Hotkey?
    var keepLoaded: Bool

    static let `default` = WhisperModelSettings(hotkey: nil, keepLoaded: false)
}

final class Settings: SettingsStorageProtocol {
    static let shared = Settings()

    private let defaults: UserDefaults

    // MARK: - Keys

    private enum Keys {
        static let toggleCloudHotkey = "toggleCloudHotkey"
        static let toggleGeminiHotkey = "toggleGeminiHotkey"
        static let cancelHotkey = "cancelHotkey"
        static let appLanguage = "appLanguage"
        static let language = "language"
        static let openaiTranscriptionModel = "openaiTranscriptionModel"
        static let geminiModel = "geminiModel"
        static let whisperModelSettings = "whisperModelSettings"
        // Legacy keys (for migration)
        static let legacyToggleLocalHotkey = "toggleLocalHotkey"
        static let legacyKeepModelLoaded = "keepModelLoaded"
        static let legacyWhisperModel = "whisperModel"
        static let legacyTranscriptionMode = "transcriptionMode"
    }

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        registerDefaults()
    }

    private func registerDefaults() {
        // Migrate old "keepDaemonRunning" → "keepModelLoaded"
        if defaults.object(forKey: Keys.legacyKeepModelLoaded) == nil,
           let oldValue = defaults.object(forKey: "keepDaemonRunning") as? Bool {
            defaults.set(oldValue, forKey: Keys.legacyKeepModelLoaded)
            defaults.removeObject(forKey: "keepDaemonRunning")
        }

        if defaults.string(forKey: Keys.language) == nil {
            defaults.set(Defaults.language, forKey: Keys.language)
        }

        // Migrate single-model settings → per-model WhisperModelSettings
        migrateToPerModelSettings()
    }

    private func migrateToPerModelSettings() {
        // Skip if already migrated
        guard defaults.data(forKey: Keys.whisperModelSettings) == nil else { return }

        let oldModel = defaults.string(forKey: Keys.legacyWhisperModel) ?? WhisperModel.small.rawValue
        let oldKeepLoaded = defaults.object(forKey: Keys.legacyKeepModelLoaded) as? Bool ?? true

        // Migrate old local hotkey
        var oldHotkey: Hotkey? = nil
        if let data = defaults.data(forKey: Keys.legacyToggleLocalHotkey),
           let hotkey = try? JSONDecoder().decode(Hotkey.self, from: data) {
            oldHotkey = hotkey
        }

        let modelSettings = WhisperModelSettings(hotkey: oldHotkey, keepLoaded: oldKeepLoaded)
        var settingsMap: [String: WhisperModelSettings] = [:]
        settingsMap[oldModel] = modelSettings

        saveWhisperModelSettings(settingsMap)

        // Clean up legacy keys
        defaults.removeObject(forKey: Keys.legacyToggleLocalHotkey)
        defaults.removeObject(forKey: Keys.legacyKeepModelLoaded)
        defaults.removeObject(forKey: Keys.legacyWhisperModel)
        defaults.removeObject(forKey: Keys.legacyTranscriptionMode)
    }

    // MARK: - Core Settings

    var language: String {
        get { defaults.string(forKey: Keys.language) ?? Defaults.language }
        set { defaults.set(newValue, forKey: Keys.language) }
    }

    var appLanguage: String {
        get { defaults.string(forKey: Keys.appLanguage) ?? "en" }
        set { defaults.set(newValue, forKey: Keys.appLanguage) }
    }

    // MARK: - Per-Model WhisperKit Settings

    func loadWhisperModelSettings() -> [String: WhisperModelSettings] {
        guard let data = defaults.data(forKey: Keys.whisperModelSettings),
              let map = try? JSONDecoder().decode([String: WhisperModelSettings].self, from: data) else {
            return [:]
        }
        return map
    }

    func saveWhisperModelSettings(_ settings: [String: WhisperModelSettings]) {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: Keys.whisperModelSettings)
        }
    }

    // MARK: - Hotkey Settings

    private func loadHotkey(key: String) -> Hotkey? {
        guard let data = defaults.data(forKey: key),
              let hotkey = try? JSONDecoder().decode(Hotkey.self, from: data) else {
            return nil
        }
        return hotkey
    }

    private func saveHotkey(key: String, hotkey: Hotkey?) {
        if let hotkey, let data = try? JSONEncoder().encode(hotkey) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    func loadToggleCloudHotkey() -> Hotkey? {
        loadHotkey(key: Keys.toggleCloudHotkey)
    }

    func saveToggleCloudHotkey(_ hotkey: Hotkey?) {
        saveHotkey(key: Keys.toggleCloudHotkey, hotkey: hotkey)
    }

    func loadCancelHotkey() -> Hotkey? {
        loadHotkey(key: Keys.cancelHotkey) ?? .cancelDefault
    }

    func saveCancelHotkey(_ hotkey: Hotkey?) {
        saveHotkey(key: Keys.cancelHotkey, hotkey: hotkey)
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

    func loadToggleGeminiHotkey() -> Hotkey? {
        loadHotkey(key: Keys.toggleGeminiHotkey)
    }

    func saveToggleGeminiHotkey(_ hotkey: Hotkey?) {
        saveHotkey(key: Keys.toggleGeminiHotkey, hotkey: hotkey)
    }
}
