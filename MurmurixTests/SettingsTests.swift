//
//  SettingsTests.swift
//  MurmurixTests
//

import Testing
import Foundation
import Carbon
@testable import Murmurix

struct SettingsTests {

    private func createSettings() -> Settings {
        // Use a unique suite name to avoid polluting real UserDefaults
        let suiteName = "com.murmurix.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return Settings(defaults: defaults)
    }

    // MARK: - Default Values

    @Test func defaultWhisperModelSettingsHasMigratedDefault() {
        let settings = createSettings()
        let map = settings.loadWhisperModelSettings()
        // Fresh install migrates with small model + default hotkey + keepLoaded=true
        #expect(map["small"] != nil)
        #expect(map["small"]?.keepLoaded == true)
        #expect(map["small"]?.hotkey == .toggleLocalDefault)
    }

    @Test func defaultLanguageIsRussian() {
        let settings = createSettings()
        #expect(settings.language == "ru")
    }

    @Test func defaultToggleCloudHotkeyIsSet() {
        let settings = createSettings()
        let hotkey = settings.loadToggleCloudHotkey()
        #expect(hotkey == Hotkey.toggleCloudDefault)
    }

    @Test func defaultCancelHotkeyIsEscape() {
        let settings = createSettings()
        let hotkey = settings.loadCancelHotkey()
        #expect(hotkey == Hotkey.cancelDefault)
    }

    @Test func defaultToggleGeminiHotkeyIsSet() {
        let settings = createSettings()
        let hotkey = settings.loadToggleGeminiHotkey()
        #expect(hotkey == Hotkey.toggleGeminiDefault)
    }

    @Test func defaultGeminiModelIsFlash2() {
        let settings = createSettings()
        #expect(settings.geminiModel == GeminiTranscriptionModel.flash2.rawValue)
    }

    // MARK: - Persistence

    @Test func whisperModelSettingsPersist() {
        let settings = createSettings()

        var map = settings.loadWhisperModelSettings()
        let hotkey = Hotkey(keyCode: 0, modifiers: UInt32(cmdKey))
        map["tiny"] = WhisperModelSettings(hotkey: hotkey, keepLoaded: true)
        settings.saveWhisperModelSettings(map)

        let loaded = settings.loadWhisperModelSettings()
        #expect(loaded["tiny"]?.hotkey == hotkey)
        #expect(loaded["tiny"]?.keepLoaded == true)
    }

    @Test func languagePersists() {
        let settings = createSettings()

        settings.language = "en"
        #expect(settings.language == "en")

        settings.language = "auto"
        #expect(settings.language == "auto")
    }

    @Test func toggleCloudHotkeyPersists() {
        let settings = createSettings()
        let newHotkey = Hotkey(keyCode: 1, modifiers: UInt32(cmdKey | shiftKey)) // Cmd+Shift+S

        settings.saveToggleCloudHotkey(newHotkey)
        let loaded = settings.loadToggleCloudHotkey()

        #expect(loaded == newHotkey)
    }

    @Test func cancelHotkeyPersists() {
        let settings = createSettings()
        let newHotkey = Hotkey(keyCode: 48, modifiers: 0) // Tab

        settings.saveCancelHotkey(newHotkey)
        let loaded = settings.loadCancelHotkey()

        #expect(loaded == newHotkey)
    }

    @Test func toggleGeminiHotkeyPersists() {
        let settings = createSettings()
        let newHotkey = Hotkey(keyCode: 4, modifiers: UInt32(cmdKey | shiftKey)) // Cmd+Shift+H

        settings.saveToggleGeminiHotkey(newHotkey)
        let loaded = settings.loadToggleGeminiHotkey()

        #expect(loaded == newHotkey)
    }

    @Test func geminiModelPersists() {
        let settings = createSettings()

        settings.geminiModel = GeminiTranscriptionModel.pro.rawValue
        #expect(settings.geminiModel == GeminiTranscriptionModel.pro.rawValue)

        settings.geminiModel = GeminiTranscriptionModel.flash.rawValue
        #expect(settings.geminiModel == GeminiTranscriptionModel.flash.rawValue)
    }

    // MARK: - Edge Cases

    @Test func loadCloudHotkeyReturnsDefaultWhenCorrupted() {
        let suiteName = "com.murmurix.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        // Write corrupted data
        defaults.set(Data([0x00, 0x01, 0x02]), forKey: "toggleCloudHotkey")

        let settings = Settings(defaults: defaults)
        let hotkey = settings.loadToggleCloudHotkey()

        #expect(hotkey == Hotkey.toggleCloudDefault)
    }
}
