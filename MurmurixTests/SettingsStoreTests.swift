import Testing
import Carbon
@testable import Murmurix

@MainActor
struct SettingsStoreTests {
    @Test func initLoadsValuesFromSettings() {
        let settings = MockSettings()
        settings.language = "en"
        settings.appLanguage = "ru"
        settings.openaiTranscriptionModel = OpenAITranscriptionModel.gpt4oMiniTranscribe.rawValue
        settings.geminiModel = GeminiTranscriptionModel.pro.rawValue
        settings.openaiApiKey = "sk-test"
        settings.geminiApiKey = "gem-test"
        settings.saveToggleCloudHotkey(Hotkey(keyCode: 1, modifiers: UInt32(cmdKey)))
        settings.saveToggleGeminiHotkey(Hotkey(keyCode: 2, modifiers: UInt32(optionKey)))
        settings.saveCancelHotkey(Hotkey(keyCode: 53, modifiers: 0))

        let store = SettingsStore(settings: settings)

        #expect(store.language == "en")
        #expect(store.appLanguage == "ru")
        #expect(store.openaiTranscriptionModel == OpenAITranscriptionModel.gpt4oMiniTranscribe.rawValue)
        #expect(store.geminiModel == GeminiTranscriptionModel.pro.rawValue)
        #expect(store.openaiApiKey == "sk-test")
        #expect(store.geminiApiKey == "gem-test")
        #expect(store.toggleCloudHotkey == Hotkey(keyCode: 1, modifiers: UInt32(cmdKey)))
        #expect(store.toggleGeminiHotkey == Hotkey(keyCode: 2, modifiers: UInt32(optionKey)))
        #expect(store.cancelHotkey == Hotkey(keyCode: 53, modifiers: 0))
    }

    @Test func updatesPersistScalarSettings() {
        let settings = MockSettings()
        let store = SettingsStore(settings: settings)

        store.language = "auto"
        store.appLanguage = "ru"
        store.openaiTranscriptionModel = OpenAITranscriptionModel.gpt4oMiniTranscribe.rawValue
        store.geminiModel = GeminiTranscriptionModel.flash.rawValue
        store.openaiApiKey = "sk-updated"
        store.geminiApiKey = "gem-updated"

        #expect(settings.language == "auto")
        #expect(settings.appLanguage == "ru")
        #expect(settings.openaiTranscriptionModel == OpenAITranscriptionModel.gpt4oMiniTranscribe.rawValue)
        #expect(settings.geminiModel == GeminiTranscriptionModel.flash.rawValue)
        #expect(settings.openaiApiKey == "sk-updated")
        #expect(settings.geminiApiKey == "gem-updated")
    }

    @Test func updatesPersistHotkeys() {
        let settings = MockSettings()
        let store = SettingsStore(settings: settings)

        let cloud = Hotkey(keyCode: 8, modifiers: UInt32(controlKey))
        let gemini = Hotkey(keyCode: 9, modifiers: UInt32(optionKey))
        let cancel = Hotkey(keyCode: 53, modifiers: UInt32(shiftKey))

        store.toggleCloudHotkey = cloud
        store.toggleGeminiHotkey = gemini
        store.cancelHotkey = cancel

        #expect(settings.loadToggleCloudHotkey() == cloud)
        #expect(settings.loadToggleGeminiHotkey() == gemini)
        #expect(settings.loadCancelHotkey() == cancel)

        store.toggleCloudHotkey = nil
        store.toggleGeminiHotkey = nil
        store.cancelHotkey = nil

        #expect(settings.loadToggleCloudHotkey() == nil)
        #expect(settings.loadToggleGeminiHotkey() == nil)
        #expect(settings.loadCancelHotkey() == nil)
    }

    @Test func initNormalizesInvalidAppLanguage() {
        let settings = MockSettings()
        settings.appLanguage = "invalid-language"

        let store = SettingsStore(settings: settings)
        #expect(store.appLanguage == AppLanguage.defaultRawValue)
    }

    @Test func invalidAppLanguageUpdateIsNormalizedBeforePersist() {
        let settings = MockSettings()
        let store = SettingsStore(settings: settings)

        store.appLanguage = "invalid-language"

        #expect(store.appLanguage == AppLanguage.defaultRawValue)
        #expect(settings.appLanguage == AppLanguage.defaultRawValue)
    }
}
