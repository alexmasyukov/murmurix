//
//  Settings.swift
//  Murmurix
//

import Foundation

final class Settings: SettingsStorageProtocol {
    static let shared = Settings()

    private let defaults: UserDefaults
    private let toggleHotkeyKey = "toggleHotkey"
    private let cancelHotkeyKey = "cancelHotkey"
    private let keepDaemonRunningKey = "keepDaemonRunning"
    private let languageKey = "language"
    private let aiPostProcessingEnabledKey = "aiPostProcessingEnabled"
    private let aiModelKey = "aiModel"
    private let aiPromptKey = "aiPrompt"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        registerDefaults()
    }

    private func registerDefaults() {
        if defaults.object(forKey: keepDaemonRunningKey) == nil {
            defaults.set(true, forKey: keepDaemonRunningKey)
        }
        if defaults.string(forKey: languageKey) == nil {
            defaults.set("ru", forKey: languageKey)
        }
    }

    // MARK: - Daemon Setting

    var keepDaemonRunning: Bool {
        get { defaults.bool(forKey: keepDaemonRunningKey) }
        set { defaults.set(newValue, forKey: keepDaemonRunningKey) }
    }

    // MARK: - Language Setting

    var language: String {
        get { defaults.string(forKey: languageKey) ?? "ru" }
        set { defaults.set(newValue, forKey: languageKey) }
    }

    // MARK: - Hotkey Settings

    func loadToggleHotkey() -> Hotkey {
        if let data = defaults.data(forKey: toggleHotkeyKey),
           let hotkey = try? JSONDecoder().decode(Hotkey.self, from: data) {
            return hotkey
        }
        return Hotkey.toggleDefault
    }

    func saveToggleHotkey(_ hotkey: Hotkey) {
        if let data = try? JSONEncoder().encode(hotkey) {
            defaults.set(data, forKey: toggleHotkeyKey)
        }
    }

    func loadCancelHotkey() -> Hotkey {
        if let data = defaults.data(forKey: cancelHotkeyKey),
           let hotkey = try? JSONDecoder().decode(Hotkey.self, from: data) {
            return hotkey
        }
        return Hotkey.cancelDefault
    }

    func saveCancelHotkey(_ hotkey: Hotkey) {
        if let data = try? JSONEncoder().encode(hotkey) {
            defaults.set(data, forKey: cancelHotkeyKey)
        }
    }

    // MARK: - AI Post-Processing Settings

    var aiPostProcessingEnabled: Bool {
        get { defaults.bool(forKey: aiPostProcessingEnabledKey) }
        set { defaults.set(newValue, forKey: aiPostProcessingEnabledKey) }
    }

    var aiModel: String {
        get { defaults.string(forKey: aiModelKey) ?? AIModel.haiku.rawValue }
        set { defaults.set(newValue, forKey: aiModelKey) }
    }

    var aiPrompt: String {
        get { defaults.string(forKey: aiPromptKey) ?? Self.defaultAIPrompt }
        set { defaults.set(newValue, forKey: aiPromptKey) }
    }

    // API key stored in Keychain for security
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

    static let defaultAIPrompt = """
        You are a post-processor for speech-to-text transcription in a software development context.

        Your task: Fix technical terms that were transcribed as Russian phonetic equivalents.

        Common replacements:
        - "кафка" → "Kafka"
        - "реакт" → "React"
        - "гоуэнг", "голэнг", "го лэнг" → "Go/Golang"
        - "питон" → "Python"
        - "джава скрипт" → "JavaScript"
        - "тайп скрипт" → "TypeScript"
        - "ноуд" → "Node.js"
        - "докер" → "Docker"
        - "кубернетис" → "Kubernetes"
        - "редис" → "Redis"
        - "постгрес" → "PostgreSQL"
        - "монго" → "MongoDB"
        - "гит" → "Git"
        - "гитхаб" → "GitHub"
        - "апи" → "API"
        - "рест" → "REST"
        - "джейсон" → "JSON"
        - "эндпоинт" → "endpoint"
        - "фреймворк" → "framework"
        - "либа", "либы" → "library/libraries"
        - "клауд", "клод" → "Claude"
        - "юз стейт" → "useState"
        - "юз эффект" → "useEffect"
        - "консоль лог" → "console.log"

        Rules:
        1. Only fix obvious technical terms, preserve the rest of the text exactly
        2. Keep punctuation and structure
        3. Return ONLY the corrected text, no explanations
        """
}
