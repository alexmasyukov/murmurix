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
}
