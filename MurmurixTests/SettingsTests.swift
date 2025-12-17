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

    @Test func defaultKeepDaemonRunningIsTrue() {
        let settings = createSettings()
        #expect(settings.keepDaemonRunning == true)
    }

    @Test func defaultLanguageIsRussian() {
        let settings = createSettings()
        #expect(settings.language == "ru")
    }

    @Test func defaultToggleHotkeyIsSet() {
        let settings = createSettings()
        let hotkey = settings.loadToggleHotkey()
        #expect(hotkey == Hotkey.toggleDefault)
    }

    @Test func defaultCancelHotkeyIsEscape() {
        let settings = createSettings()
        let hotkey = settings.loadCancelHotkey()
        #expect(hotkey == Hotkey.cancelDefault)
    }

    // MARK: - Persistence

    @Test func keepDaemonRunningPersists() {
        let settings = createSettings()

        settings.keepDaemonRunning = false
        #expect(settings.keepDaemonRunning == false)

        settings.keepDaemonRunning = true
        #expect(settings.keepDaemonRunning == true)
    }

    @Test func languagePersists() {
        let settings = createSettings()

        settings.language = "en"
        #expect(settings.language == "en")

        settings.language = "auto"
        #expect(settings.language == "auto")
    }

    @Test func toggleHotkeyPersists() {
        let settings = createSettings()
        let newHotkey = Hotkey(keyCode: 0, modifiers: UInt32(cmdKey | shiftKey)) // Cmd+Shift+A

        settings.saveToggleHotkey(newHotkey)
        let loaded = settings.loadToggleHotkey()

        #expect(loaded == newHotkey)
    }

    @Test func cancelHotkeyPersists() {
        let settings = createSettings()
        let newHotkey = Hotkey(keyCode: 48, modifiers: 0) // Tab

        settings.saveCancelHotkey(newHotkey)
        let loaded = settings.loadCancelHotkey()

        #expect(loaded == newHotkey)
    }

    // MARK: - Edge Cases

    @Test func loadToggleHotkeyReturnsDefaultWhenCorrupted() {
        let suiteName = "com.murmurix.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        // Write corrupted data
        defaults.set(Data([0x00, 0x01, 0x02]), forKey: "toggleHotkey")

        let settings = Settings(defaults: defaults)
        let hotkey = settings.loadToggleHotkey()

        #expect(hotkey == Hotkey.toggleDefault)
    }
}
