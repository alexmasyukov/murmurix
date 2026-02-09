//
//  SettingsStore.swift
//  Murmurix
//

import Foundation
import Combine

@MainActor
final class SettingsStore: ObservableObject {
    private let settings: SettingsStorageProtocol

    @Published var language: String {
        didSet {
            guard language != oldValue else { return }
            settings.language = language
        }
    }

    @Published var appLanguage: String {
        didSet {
            guard appLanguage != oldValue else { return }
            settings.appLanguage = appLanguage
        }
    }

    @Published var openaiTranscriptionModel: String {
        didSet {
            guard openaiTranscriptionModel != oldValue else { return }
            settings.openaiTranscriptionModel = openaiTranscriptionModel
        }
    }

    @Published var geminiModel: String {
        didSet {
            guard geminiModel != oldValue else { return }
            settings.geminiModel = geminiModel
        }
    }

    @Published var openaiApiKey: String {
        didSet {
            guard openaiApiKey != oldValue else { return }
            settings.openaiApiKey = openaiApiKey
        }
    }

    @Published var geminiApiKey: String {
        didSet {
            guard geminiApiKey != oldValue else { return }
            settings.geminiApiKey = geminiApiKey
        }
    }

    @Published var toggleCloudHotkey: Hotkey? {
        didSet {
            guard toggleCloudHotkey != oldValue else { return }
            settings.saveToggleCloudHotkey(toggleCloudHotkey)
        }
    }

    @Published var toggleGeminiHotkey: Hotkey? {
        didSet {
            guard toggleGeminiHotkey != oldValue else { return }
            settings.saveToggleGeminiHotkey(toggleGeminiHotkey)
        }
    }

    @Published var cancelHotkey: Hotkey? {
        didSet {
            guard cancelHotkey != oldValue else { return }
            settings.saveCancelHotkey(cancelHotkey)
        }
    }

    init(settings: SettingsStorageProtocol) {
        self.settings = settings
        self.language = settings.language
        self.appLanguage = settings.appLanguage
        self.openaiTranscriptionModel = settings.openaiTranscriptionModel
        self.geminiModel = settings.geminiModel
        self.openaiApiKey = settings.openaiApiKey
        self.geminiApiKey = settings.geminiApiKey
        self.toggleCloudHotkey = settings.loadToggleCloudHotkey()
        self.toggleGeminiHotkey = settings.loadToggleGeminiHotkey()
        self.cancelHotkey = settings.loadCancelHotkey()
    }
}
