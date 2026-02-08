//
//  L10n.swift
//  Murmurix
//

import Foundation

enum L10n {
    private static func tr(_ en: String, _ ru: String, _ es: String) -> String {
        switch AppLanguage.current {
        case .en: return en
        case .ru: return ru
        case .es: return es
        }
    }

    // MARK: - Settings Sections

    static var appLanguage: String { tr("App Language", "Язык приложения", "Idioma de la app") }
    static var keyboardShortcuts: String { tr("Keyboard Shortcuts", "Горячие клавиши", "Atajos de teclado") }
    static var recognition: String { tr("Recognition", "Распознавание", "Reconocimiento") }
    static var localModels: String { tr("Local Models", "Локальные модели", "Modelos locales") }
    static var modelManagement: String { tr("Model Management", "Управление моделями", "Gestión de modelos") }
    static var cloudOpenAI: String { tr("Cloud (OpenAI)", "Облако (OpenAI)", "Nube (OpenAI)") }
    static var cloudGemini: String { tr("Cloud (Gemini)", "Облако (Gemini)", "Nube (Gemini)") }

    // MARK: - Keyboard Shortcuts

    static var cloudRecordingOpenAI: String { tr("Cloud Recording (OpenAI)", "Облачная запись (OpenAI)", "Grabación en la nube (OpenAI)") }
    static var recordWithOpenAI: String { tr("Record with OpenAI cloud API", "Запись через облачный API OpenAI", "Grabar con la API de OpenAI") }
    static var geminiRecording: String { tr("Gemini Recording", "Запись Gemini", "Grabación Gemini") }
    static var recordWithGemini: String { tr("Record with Google Gemini API", "Запись через API Google Gemini", "Grabar con la API de Google Gemini") }
    static var cancelRecording: String { tr("Cancel Recording", "Отмена записи", "Cancelar grabación") }
    static var discardsRecording: String { tr("Discards the active recording", "Отменяет активную запись", "Descarta la grabación activa") }
    static var pressKeys: String { tr("Press keys...", "Нажмите клавиши...", "Pulse teclas...") }

    // MARK: - Recognition

    static var language: String { tr("Language", "Язык", "Idioma") }
    static var recognitionLanguage: String { tr("Recognition language", "Язык распознавания", "Idioma de reconocimiento") }
    static var russian: String { tr("Russian", "Русский", "Ruso") }
    static var english: String { tr("English", "Английский", "Inglés") }
    static var autoDetect: String { tr("Auto-detect", "Авто", "Autodetectar") }
    static var model: String { tr("Model", "Модель", "Modelo") }

    // MARK: - Model Card

    static var installed: String { tr("Installed", "Установлена", "Instalado") }
    static var notInstalled: String { tr("Not installed", "Не установлена", "No instalado") }
    static var hotkey: String { tr("Hotkey", "Горячая клавиша", "Atajo") }
    static var notSet: String { tr("Not set", "Не задана", "No asignado") }
    static var keepInMemory: String { tr("Keep in memory", "Держать в памяти", "Mantener en memoria") }
    static var test: String { tr("Test", "Тест", "Probar") }
    static var testing: String { tr("Testing...", "Тестирование...", "Probando...") }
    static var delete: String { tr("Delete", "Удалить", "Eliminar") }
    static var deleteModel: String { tr("Delete model?", "Удалить модель?", "¿Eliminar modelo?") }
    static var cancel: String { tr("Cancel", "Отмена", "Cancelar") }
    static var modelFile: String { tr("Model file", "Файл модели", "Archivo del modelo") }
    static var download: String { tr("Download", "Скачать", "Descargar") }
    static var compiling: String { tr("Compiling...", "Компиляция...", "Compilando...") }
    static var ready: String { tr("Ready!", "Готово!", "¡Listo!") }
    static var retry: String { tr("Retry", "Повторить", "Reintentar") }
    static var modelWorksCorrectly: String { tr("Model works correctly", "Модель работает корректно", "El modelo funciona correctamente") }
    static var connectionSuccessful: String { tr("Connection successful", "Подключение успешно", "Conexión exitosa") }

    static func downloading(progress: Int) -> String {
        tr("Downloading... \(progress)%", "Загрузка... \(progress)%", "Descargando... \(progress)%")
    }

    static func deleteModelMessage(_ name: String) -> String {
        tr(
            "Model \"\(name)\" will be removed from disk and unloaded from memory.",
            "Модель \"\(name)\" будет удалена с диска и выгружена из памяти.",
            "El modelo \"\(name)\" se eliminará del disco y se descargará de la memoria."
        )
    }

    // MARK: - Delete All Models

    static var deleteAllModels: String { tr("Delete all models", "Удалить все модели", "Eliminar todos los modelos") }
    static var deleteAllModelsQuestion: String { tr("Delete all models?", "Удалить все модели?", "¿Eliminar todos los modelos?") }
    static var deleteAll: String { tr("Delete all", "Удалить все", "Eliminar todos") }
    static var removesAllModelsDescription: String {
        tr(
            "Removes all downloaded models from disk and unloads from memory",
            "Удаляет все загруженные модели с диска и выгружает из памяти",
            "Elimina todos los modelos descargados del disco y los descarga de la memoria"
        )
    }

    static func deleteAllModelsMessage(count: Int) -> String {
        tr(
            "All \(count) downloaded models will be removed from disk and unloaded from memory.",
            "Все \(count) загруженные модели будут удалены с диска и выгружены из памяти.",
            "Los \(count) modelos descargados se eliminarán del disco y se descargarán de la memoria."
        )
    }

    // MARK: - API Key

    static var apiKey: String { tr("API Key", "API-ключ", "Clave API") }

    // MARK: - History

    static var clearHistory: String { tr("Clear History", "Очистить историю", "Borrar historial") }
    static var clearAll: String { tr("Clear All", "Очистить все", "Borrar todo") }
    static var selectTranscription: String { tr("Select a transcription", "Выберите запись", "Seleccione una transcripción") }
    static var recordings: String { tr("recordings", "записей", "grabaciones") }
    static var totalTime: String { tr("total time", "общее время", "tiempo total") }
    static var words: String { tr("words", "слов", "palabras") }
    static var copied: String { tr("Copied!", "Скопировано!", "¡Copiado!") }
    static var copy: String { tr("Copy", "Копировать", "Copiar") }

    static func clearHistoryMessage(count: Int) -> String {
        tr(
            "Are you sure you want to delete all \(count) recordings? This cannot be undone.",
            "Вы уверены, что хотите удалить все \(count) записей? Это действие нельзя отменить.",
            "¿Está seguro de que desea eliminar las \(count) grabaciones? Esta acción no se puede deshacer."
        )
    }

    static func itemsCount(_ count: Int) -> String {
        tr("\(count) items", "\(count) записей", "\(count) elementos")
    }

    // MARK: - Menu Bar

    static func localModel(_ name: String) -> String {
        tr("Local: \(name)", "Локальная: \(name)", "Local: \(name)")
    }

    static var history: String { tr("History...", "История...", "Historial...") }
    static var settings: String { tr("Settings...", "Настройки...", "Ajustes...") }
    static var quit: String { tr("Quit", "Выход", "Salir") }

    // MARK: - Window Titles

    static var settingsTitle: String { tr("Settings", "Настройки", "Ajustes") }
    static var historyTitle: String { tr("Transcription History", "История транскрипций", "Historial de transcripciones") }

    // MARK: - App Menu

    static var quitMurmurix: String { tr("Quit Murmurix", "Завершить Murmurix", "Salir de Murmurix") }
    static var edit: String { tr("Edit", "Правка", "Editar") }
    static var undo: String { tr("Undo", "Отменить", "Deshacer") }
    static var redo: String { tr("Redo", "Повторить", "Rehacer") }
    static var cut: String { tr("Cut", "Вырезать", "Cortar") }
    static var paste: String { tr("Paste", "Вставить", "Pegar") }
    static var selectAll: String { tr("Select All", "Выделить все", "Seleccionar todo") }

    // MARK: - Errors

    static func error(_ message: String) -> String {
        tr("Error: \(message)", "Ошибка: \(message)", "Error: \(message)")
    }

    // MARK: - Whisper Model Descriptions

    static func whisperModelDescription(_ model: WhisperModel) -> String {
        switch model {
        case .tiny: return tr("Fastest, ~70 MB", "Быстрейшая, ~70 МБ", "La más rápida, ~70 MB")
        case .base: return "~140 MB"
        case .small: return "~290 MB"
        case .medium: return "~800 MB"
        case .largeV2: return tr("~2.5 GB", "~2,5 ГБ", "~2,5 GB")
        case .largeV3: return tr("Best quality, ~2.5 GB", "Лучшее качество, ~2,5 ГБ", "Mejor calidad, ~2,5 GB")
        }
    }
}
