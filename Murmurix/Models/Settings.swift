//
//  Settings.swift
//  Murmurix
//

import Foundation

enum WhisperModel: String, CaseIterable {
    case tiny = "tiny"
    case base = "base"
    case small = "small"
    case medium = "medium"
    case largeV2 = "large-v2"
    case largeV3 = "large-v3"

    var displayName: String {
        switch self {
        case .tiny: return "Tiny (fastest, ~75MB)"
        case .base: return "Base (~140MB)"
        case .small: return "Small (~460MB)"
        case .medium: return "Medium (~1.5GB)"
        case .largeV2: return "Large v2 (~3GB)"
        case .largeV3: return "Large v3 (best, ~3GB)"
        }
    }

    var isInstalled: Bool {
        // Check Hugging Face cache
        let hfCache = NSHomeDirectory() + "/.cache/huggingface/hub/models--Systran--faster-whisper-\(rawValue)"
        let snapshotsPath = hfCache + "/snapshots"

        guard FileManager.default.fileExists(atPath: snapshotsPath) else { return false }

        // Check if any snapshot has model files
        guard let snapshots = try? FileManager.default.contentsOfDirectory(atPath: snapshotsPath) else { return false }

        for snapshot in snapshots {
            let modelBin = snapshotsPath + "/\(snapshot)/model.bin"
            let configJson = snapshotsPath + "/\(snapshot)/config.json"
            if FileManager.default.fileExists(atPath: modelBin) || FileManager.default.fileExists(atPath: configJson) {
                return true
            }
        }
        return false
    }

    static var installedModels: [WhisperModel] {
        allCases.filter { $0.isInstalled }
    }
}

final class Settings: SettingsStorageProtocol {
    static let shared = Settings()

    private let defaults: UserDefaults
    private let toggleHotkeyKey = "toggleHotkey"
    private let cancelHotkeyKey = "cancelHotkey"
    private let keepDaemonRunningKey = "keepDaemonRunning"
    private let languageKey = "language"
    private let whisperModelKey = "whisperModel"
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

    // MARK: - Whisper Model Setting

    var whisperModel: String {
        get { defaults.string(forKey: whisperModelKey) ?? WhisperModel.small.rawValue }
        set { defaults.set(newValue, forKey: whisperModelKey) }
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
        Ты пост-процессор для голосовых транскрипций.

        Контекст: обсуждение программирования на Golang, Swift, Kotlin, построение архитектуры, системы очередей, фронтенд.

        Задачи:
        1. Замени распознанные названия сервисов, библиотек, фреймворков, инструментов на их оригинальные английские названия
        2. Исправь орфографические ошибки в словах

        Частые замены:
        - "кафка" → "Kafka"
        - "реакт" → "React"
        - "гоуэнг", "голэнг", "го лэнг" → "Golang"
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

        Правила:
        1. Сохраняй структуру и смысл текста
        2. Не добавляй ничего лишнего
        """
}
