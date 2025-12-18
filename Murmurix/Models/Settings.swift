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
        static let toggleHotkey = "toggleHotkey"
        static let toggleNoAIHotkey = "toggleNoAIHotkey"
        static let cancelHotkey = "cancelHotkey"
        static let keepDaemonRunning = "keepDaemonRunning"
        static let language = "language"
        static let whisperModel = "whisperModel"
        static let aiPostProcessingEnabled = "aiPostProcessingEnabled"
        static let aiModel = "aiModel"
        static let aiPrompt = "aiPrompt"
    }

    // MARK: - Defaults

    static let defaultAIPrompt = AIConfig.defaultPrompt

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

    func loadToggleHotkey() -> Hotkey {
        guard let data = defaults.data(forKey: Keys.toggleHotkey),
              let hotkey = try? JSONDecoder().decode(Hotkey.self, from: data) else {
            return .toggleDefault
        }
        return hotkey
    }

    func saveToggleHotkey(_ hotkey: Hotkey) {
        if let data = try? JSONEncoder().encode(hotkey) {
            defaults.set(data, forKey: Keys.toggleHotkey)
        }
    }

    func loadToggleNoAIHotkey() -> Hotkey {
        guard let data = defaults.data(forKey: Keys.toggleNoAIHotkey),
              let hotkey = try? JSONDecoder().decode(Hotkey.self, from: data) else {
            return .toggleNoAIDefault
        }
        return hotkey
    }

    func saveToggleNoAIHotkey(_ hotkey: Hotkey) {
        if let data = try? JSONEncoder().encode(hotkey) {
            defaults.set(data, forKey: Keys.toggleNoAIHotkey)
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

    // MARK: - AI Settings

    var aiPostProcessingEnabled: Bool {
        get { defaults.bool(forKey: Keys.aiPostProcessingEnabled) }
        set { defaults.set(newValue, forKey: Keys.aiPostProcessingEnabled) }
    }

    var aiModel: String {
        get { defaults.string(forKey: Keys.aiModel) ?? AIModel.haiku.rawValue }
        set { defaults.set(newValue, forKey: Keys.aiModel) }
    }

    var aiPrompt: String {
        get { defaults.string(forKey: Keys.aiPrompt) ?? Self.defaultAIPrompt }
        set { defaults.set(newValue, forKey: Keys.aiPrompt) }
    }

    var claudeApiKey: String {
        get { KeychainService.load(key: "claudeApiKey") ?? "" }
        set {
            if newValue.isEmpty {
                KeychainService.delete(key: "claudeApiKey")
            } else {
                KeychainService.save(key: "claudeApiKey", value: newValue)
            }
        }
    }
}
