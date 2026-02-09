//
//  MenuBarManager.swift
//  Murmurix
//

import AppKit
import Carbon

@MainActor
protocol MenuBarManagerDelegate: AnyObject {
    func menuBarDidRequestToggleLocalRecording(model: String)
    func menuBarDidRequestToggleCloudRecording()
    func menuBarDidRequestToggleGeminiRecording()
    func menuBarDidRequestOpenHistory()
    func menuBarDidRequestOpenSettings()
    func menuBarDidRequestQuit()
}

@MainActor
final class MenuBarManager {
    weak var delegate: MenuBarManagerDelegate?

    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var localModelMenuItems: [String: NSMenuItem] = [:]
    private var toggleCloudMenuItem: NSMenuItem?
    private var toggleGeminiMenuItem: NSMenuItem?
    private let settings: SettingsStorageProtocol

    init(settings: SettingsStorageProtocol = Settings.shared) {
        self.settings = settings
    }

    func setup() {
        setupStatusItem()
        setupMenu()
    }

    func rebuildMenu() {
        setupMenu()
    }

    func updateHotkeyDisplay() {
        applyHotkeyIfPresent(to: toggleCloudMenuItem, hotkey: settings.loadToggleCloudHotkey())
        applyHotkeyIfPresent(to: toggleGeminiMenuItem, hotkey: settings.loadToggleGeminiHotkey())
    }

    func updateLocalModelMenuItems(hotkeys: [String: Hotkey]) {
        // Remove existing local model items
        for (_, item) in localModelMenuItems {
            menu.removeItem(item)
        }
        localModelMenuItems.removeAll()

        // Insert new local model items at the beginning
        var insertIndex = 0
        for model in WhisperModel.allCases {
            guard let hotkey = hotkeys[model.rawValue] else { continue }
            let item = makeLocalModelMenuItem(modelName: model.rawValue, hotkey: hotkey)
            menu.insertItem(item, at: insertIndex)
            localModelMenuItems[model.rawValue] = item
            insertIndex += 1
        }
    }

    // MARK: - Private Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Murmurix")
        }
    }

    private func setupMenu() {
        menu = NSMenu()
        localModelMenuItems.removeAll()

        // Add local model items from settings
        let modelSettings = settings.loadWhisperModelSettings()
        for model in WhisperModel.allCases {
            guard let hotkey = modelSettings[model.rawValue]?.hotkey else { continue }
            let item = makeLocalModelMenuItem(modelName: model.rawValue, hotkey: hotkey)
            menu.addItem(item)
            localModelMenuItems[model.rawValue] = item
        }

        let cloudMenuItem = makeCloudMenuItem(
            title: L10n.cloudRecordingOpenAI,
            action: #selector(handleToggleCloudRecording),
            hotkey: settings.loadToggleCloudHotkey()
        )
        toggleCloudMenuItem = cloudMenuItem
        menu.addItem(cloudMenuItem)

        let geminiMenuItem = makeCloudMenuItem(
            title: L10n.geminiRecording,
            action: #selector(handleToggleGeminiRecording),
            hotkey: settings.loadToggleGeminiHotkey()
        )
        toggleGeminiMenuItem = geminiMenuItem
        menu.addItem(geminiMenuItem)

        menu.addItem(NSMenuItem.separator())

        let historyItem = NSMenuItem(
            title: L10n.history,
            action: #selector(handleOpenHistory),
            keyEquivalent: "h"
        )
        historyItem.target = self
        menu.addItem(historyItem)

        let settingsItem = NSMenuItem(
            title: L10n.settings,
            action: #selector(handleOpenSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: L10n.quit,
            action: #selector(handleQuit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func applyHotkeyToMenuItem(_ menuItem: NSMenuItem, hotkey: Hotkey) {
        if let keyString = Hotkey.keyCodeToName(hotkey.keyCode)?.lowercased() {
            menuItem.keyEquivalent = keyString
        }

        var modifiers: NSEvent.ModifierFlags = []
        if hotkey.modifiers & UInt32(cmdKey) != 0 { modifiers.insert(.command) }
        if hotkey.modifiers & UInt32(optionKey) != 0 { modifiers.insert(.option) }
        if hotkey.modifiers & UInt32(controlKey) != 0 { modifiers.insert(.control) }
        if hotkey.modifiers & UInt32(shiftKey) != 0 { modifiers.insert(.shift) }
        menuItem.keyEquivalentModifierMask = modifiers
    }

    private func applyHotkeyIfPresent(to menuItem: NSMenuItem?, hotkey: Hotkey?) {
        guard let menuItem, let hotkey else { return }
        applyHotkeyToMenuItem(menuItem, hotkey: hotkey)
    }

    private func makeLocalModelMenuItem(modelName: String, hotkey: Hotkey) -> NSMenuItem {
        let item = NSMenuItem(
            title: L10n.localModel(modelName),
            action: #selector(handleToggleLocalRecording(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.representedObject = modelName
        applyHotkeyToMenuItem(item, hotkey: hotkey)
        return item
    }

    private func makeCloudMenuItem(title: String, action: Selector, hotkey: Hotkey?) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        applyHotkeyIfPresent(to: item, hotkey: hotkey)
        return item
    }

    // MARK: - Actions

    @objc private func handleToggleLocalRecording(_ sender: NSMenuItem) {
        guard let modelName = sender.representedObject as? String else { return }
        delegate?.menuBarDidRequestToggleLocalRecording(model: modelName)
    }

    @objc private func handleToggleCloudRecording() {
        delegate?.menuBarDidRequestToggleCloudRecording()
    }

    @objc private func handleToggleGeminiRecording() {
        delegate?.menuBarDidRequestToggleGeminiRecording()
    }

    @objc private func handleOpenHistory() {
        delegate?.menuBarDidRequestOpenHistory()
    }

    @objc private func handleOpenSettings() {
        delegate?.menuBarDidRequestOpenSettings()
    }

    @objc private func handleQuit() {
        delegate?.menuBarDidRequestQuit()
    }
}
