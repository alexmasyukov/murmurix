//
//  MenuBarManagerTests.swift
//  MurmurixTests
//
//  Delegate-mock tests for menu bar items. These do not exercise the system
//  status bar (that lives in SystemUIServer and is unreliable under XCUITest);
//  instead they trigger NSMenuItem actions directly and assert that the
//  delegate hooks fire. This is the right unit-test layer for MenuBarManager
//  because the production code already isolates the "what to do on click"
//  logic behind MenuBarManagerDelegate.
//

import Testing
import AppKit
@testable import Murmurix

// MARK: - Mock delegate

@MainActor
final class MockMenuBarDelegate: MenuBarManagerDelegate {
    var toggleLocalCalls: [String] = []
    var toggleCloudCalls = 0
    var toggleGeminiCalls = 0
    var openHistoryCalls = 0
    var openSettingsCalls = 0
    var quitCalls = 0

    func menuBarDidRequestToggleLocalRecording(model: String) { toggleLocalCalls.append(model) }
    func menuBarDidRequestToggleCloudRecording() { toggleCloudCalls += 1 }
    func menuBarDidRequestToggleGeminiRecording() { toggleGeminiCalls += 1 }
    func menuBarDidRequestOpenHistory() { openHistoryCalls += 1 }
    func menuBarDidRequestOpenSettings() { openSettingsCalls += 1 }
    func menuBarDidRequestQuit() { quitCalls += 1 }
}

// MARK: - Helpers

@MainActor
private func makeManager(
    settings: SettingsStorageProtocol? = nil
) -> (MenuBarManager, MockMenuBarDelegate) {
    let manager = MenuBarManager(settings: settings ?? MockSettings())
    let delegate = MockMenuBarDelegate()
    manager.delegate = delegate
    manager.setup()
    return (manager, delegate)
}

/// Synchronously triggers the NSMenuItem's target/action pair — the same path
/// AppKit takes when the user clicks the item in the menu bar.
@MainActor
private func perform(_ item: NSMenuItem?) {
    guard let item, let target = item.target, let action = item.action else { return }
    _ = target.perform(action, with: item)
}

// MARK: - Static menu items

@MainActor
struct MenuBarManagerStaticItemsTests {
    @Test func settingsItemTriggersDelegate() {
        let (manager, delegate) = makeManager()
        let item = manager.menu?.item(withAccessibilityIdentifier: MenuBarManager.AccessibilityID.settings)
        perform(item)
        #expect(delegate.openSettingsCalls == 1)
    }

    @Test func historyItemTriggersDelegate() {
        let (manager, delegate) = makeManager()
        let item = manager.menu?.item(withAccessibilityIdentifier: MenuBarManager.AccessibilityID.history)
        perform(item)
        #expect(delegate.openHistoryCalls == 1)
    }

    @Test func quitItemTriggersDelegate() {
        let (manager, delegate) = makeManager()
        let item = manager.menu?.item(withAccessibilityIdentifier: MenuBarManager.AccessibilityID.quit)
        perform(item)
        #expect(delegate.quitCalls == 1)
    }

    @Test func cloudOpenAIItemTriggersDelegate() {
        let (manager, delegate) = makeManager()
        let item = manager.menu?.item(withAccessibilityIdentifier: MenuBarManager.AccessibilityID.cloudOpenAI)
        perform(item)
        #expect(delegate.toggleCloudCalls == 1)
    }

    @Test func cloudGeminiItemTriggersDelegate() {
        let (manager, delegate) = makeManager()
        let item = manager.menu?.item(withAccessibilityIdentifier: MenuBarManager.AccessibilityID.cloudGemini)
        perform(item)
        #expect(delegate.toggleGeminiCalls == 1)
    }

    @Test func statusItemButtonHasAccessibilityIdentifier() {
        let (manager, _) = makeManager()
        #expect(manager.statusItem?.button?.accessibilityIdentifier() == MenuBarManager.AccessibilityID.statusItemButton)
    }
}

// MARK: - Local model items (built from settings)

@MainActor
struct MenuBarManagerLocalModelItemsTests {
    @Test func localModelMenuItemIsInsertedWhenHotkeyAssigned() {
        let settings = MockSettings()
        let hotkey = Hotkey(keyCode: 17, modifiers: 0)
        settings.saveWhisperModelSettings([
            "tiny": WhisperModelSettings(hotkey: hotkey, keepLoaded: false)
        ])

        let (manager, _) = makeManager(settings: settings)

        let tinyItem = manager.menu?.item(withAccessibilityIdentifier: MenuBarManager.AccessibilityID.localModel("tiny"))
        #expect(tinyItem != nil, "Expected a local model menu item once a hotkey is assigned")
    }

    @Test func clickingLocalModelItemPassesNameToDelegate() {
        let settings = MockSettings()
        settings.saveWhisperModelSettings([
            "small": WhisperModelSettings(hotkey: Hotkey(keyCode: 1, modifiers: 0), keepLoaded: false)
        ])

        let (manager, delegate) = makeManager(settings: settings)

        let smallItem = manager.menu?.item(withAccessibilityIdentifier: MenuBarManager.AccessibilityID.localModel("small"))
        perform(smallItem)

        #expect(delegate.toggleLocalCalls == ["small"])
    }

    @Test func updateLocalModelMenuItemsReplacesExisting() {
        let settings = MockSettings()
        settings.saveWhisperModelSettings([
            "tiny": WhisperModelSettings(hotkey: Hotkey(keyCode: 17, modifiers: 0), keepLoaded: false)
        ])

        let (manager, _) = makeManager(settings: settings)

        // Replace the assignment: drop tiny, add small.
        manager.updateLocalModelMenuItems(hotkeys: [
            "small": Hotkey(keyCode: 1, modifiers: 0)
        ])

        #expect(manager.menu?.item(withAccessibilityIdentifier: MenuBarManager.AccessibilityID.localModel("tiny")) == nil)
        #expect(manager.menu?.item(withAccessibilityIdentifier: MenuBarManager.AccessibilityID.localModel("small")) != nil)
    }
}

// MARK: - NSMenu helper

private extension NSMenu {
    func item(withAccessibilityIdentifier identifier: String) -> NSMenuItem? {
        items.first { $0.accessibilityIdentifier() == identifier }
    }
}
