//
//  L10n.swift
//  Murmurix
//

import Foundation

enum L10n {
    private static func tr(_ en: String, _ ru: String) -> String {
        AppLanguage.current == .en ? en : ru
    }

    // MARK: - Settings Sections

    static var appLanguage: String { tr("App Language", "Язык приложения") }
    static var keyboardShortcuts: String { tr("Keyboard Shortcuts", "Горячие клавиши") }
    static var recognition: String { tr("Recognition", "Распознавание") }
    static var localModels: String { tr("Local Models", "Локальные модели") }
    static var modelManagement: String { tr("Model Management", "Управление моделями") }
    static var cloudOpenAI: String { tr("Cloud (OpenAI)", "Облако (OpenAI)") }
    static var cloudGemini: String { tr("Cloud (Gemini)", "Облако (Gemini)") }

    // MARK: - Keyboard Shortcuts

    static var cloudRecordingOpenAI: String { tr("Cloud Recording (OpenAI)", "Облачная запись (OpenAI)") }
    static var recordWithOpenAI: String { tr("Record with OpenAI cloud API", "Запись через облачный API OpenAI") }
    static var geminiRecording: String { tr("Gemini Recording", "Запись Gemini") }
    static var recordWithGemini: String { tr("Record with Google Gemini API", "Запись через API Google Gemini") }
    static var cancelRecording: String { tr("Cancel Recording", "Отмена записи") }
    static var discardsRecording: String { tr("Discards the active recording", "Отменяет активную запись") }
    static var pressKeys: String { tr("Press keys...", "Нажмите клавиши...") }

    // MARK: - Recognition

    static var language: String { tr("Language", "Язык") }
    static var russian: String { tr("Russian", "Русский") }
    static var english: String { tr("English", "Английский") }
    static var autoDetect: String { tr("Auto-detect", "Авто") }
    static var model: String { tr("Model", "Модель") }

    // MARK: - Model Card

    static var installed: String { tr("Installed", "Установлена") }
    static var notInstalled: String { tr("Not installed", "Не установлена") }
    static var hotkey: String { tr("Hotkey", "Горячая клавиша") }
    static var notSet: String { tr("Not set", "Не задана") }
    static var keepInMemory: String { tr("Keep in memory", "Держать в памяти") }
    static var test: String { tr("Test", "Тест") }
    static var testing: String { tr("Testing...", "Тестирование...") }
    static var delete: String { tr("Delete", "Удалить") }
    static var deleteModel: String { tr("Delete model?", "Удалить модель?") }
    static var cancel: String { tr("Cancel", "Отмена") }
    static var download: String { tr("Download", "Скачать") }
    static var compiling: String { tr("Compiling...", "Компиляция...") }
    static var ready: String { tr("Ready!", "Готово!") }
    static var retry: String { tr("Retry", "Повторить") }
    static var modelWorksCorrectly: String { tr("Model works correctly", "Модель работает корректно") }
    static var connectionSuccessful: String { tr("Connection successful", "Подключение успешно") }

    static func downloading(progress: Int) -> String {
        tr("Downloading... \(progress)%", "Загрузка... \(progress)%")
    }

    static func deleteModelMessage(_ name: String) -> String {
        tr(
            "Model \"\(name)\" will be removed from disk and unloaded from memory.",
            "Модель \"\(name)\" будет удалена с диска и выгружена из памяти."
        )
    }

    // MARK: - Delete All Models

    static var deleteAllModels: String { tr("Delete all models", "Удалить все модели") }
    static var deleteAllModelsQuestion: String { tr("Delete all models?", "Удалить все модели?") }
    static var deleteAll: String { tr("Delete all", "Удалить все") }
    static var removesAllModelsDescription: String {
        tr(
            "Removes all downloaded models from disk and unloads from memory",
            "Удаляет все загруженные модели с диска и выгружает из памяти"
        )
    }

    static func deleteAllModelsMessage(count: Int) -> String {
        tr(
            "All \(count) downloaded models will be removed from disk and unloaded from memory.",
            "Все \(count) загруженные модели будут удалены с диска и выгружены из памяти."
        )
    }

    // MARK: - API Key

    static var apiKey: String { tr("API Key", "API-ключ") }

    // MARK: - History

    static var clearHistory: String { tr("Clear History", "Очистить историю") }
    static var clearAll: String { tr("Clear All", "Очистить все") }
    static var selectTranscription: String { tr("Select a transcription", "Выберите запись") }
    static var recordings: String { tr("recordings", "записей") }
    static var totalTime: String { tr("total time", "общее время") }
    static var words: String { tr("words", "слов") }
    static var copied: String { tr("Copied!", "Скопировано!") }
    static var copy: String { tr("Copy", "Копировать") }

    static func clearHistoryMessage(count: Int) -> String {
        tr(
            "Are you sure you want to delete all \(count) recordings? This cannot be undone.",
            "Вы уверены, что хотите удалить все \(count) записей? Это действие нельзя отменить."
        )
    }

    static func itemsCount(_ count: Int) -> String {
        tr("\(count) items", "\(count) записей")
    }

    // MARK: - Menu Bar

    static func localModel(_ name: String) -> String {
        tr("Local: \(name)", "Локальная: \(name)")
    }

    static var history: String { tr("History...", "История...") }
    static var settings: String { tr("Settings...", "Настройки...") }
    static var quit: String { tr("Quit", "Выход") }

    // MARK: - Window Titles

    static var settingsTitle: String { tr("Settings", "Настройки") }
    static var historyTitle: String { tr("Transcription History", "История транскрипций") }

    // MARK: - App Menu

    static var quitMurmurix: String { tr("Quit Murmurix", "Завершить Murmurix") }
    static var edit: String { tr("Edit", "Правка") }
    static var undo: String { tr("Undo", "Отменить") }
    static var redo: String { tr("Redo", "Повторить") }
    static var cut: String { tr("Cut", "Вырезать") }
    static var paste: String { tr("Paste", "Вставить") }
    static var selectAll: String { tr("Select All", "Выделить все") }

    // MARK: - Errors

    static func error(_ message: String) -> String {
        tr("Error: \(message)", "Ошибка: \(message)")
    }

    // MARK: - Whisper Model Display Names

    static func whisperModelDisplayName(_ model: WhisperModel) -> String {
        switch model {
        case .tiny: return tr("Tiny (fastest, ~75MB)", "Tiny (быстрейшая, ~75МБ)")
        case .base: return tr("Base (~140MB)", "Base (~140МБ)")
        case .small: return tr("Small (~460MB)", "Small (~460МБ)")
        case .medium: return tr("Medium (~1.5GB)", "Medium (~1,5ГБ)")
        case .largeV2: return tr("Large v2 (~3GB)", "Large v2 (~3ГБ)")
        case .largeV3: return tr("Large v3 (best, ~3GB)", "Large v3 (лучшая, ~3ГБ)")
        }
    }
}
