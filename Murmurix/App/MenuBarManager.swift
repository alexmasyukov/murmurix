//
//  MenuBarManager.swift
//  Murmurix
//

import AppKit
import Carbon

protocol MenuBarManagerDelegate: AnyObject {
    func menuBarDidRequestToggleLocalRecording(model: String)
    func menuBarDidRequestToggleCloudRecording()
    func menuBarDidRequestToggleGeminiRecording()
    func menuBarDidRequestOpenHistory()
    func menuBarDidRequestOpenSettings()
    func menuBarDidRequestQuit()
}

final class MenuBarManager {
    weak var delegate: MenuBarManagerDelegate?

    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var localModelMenuItems: [String: NSMenuItem] = [:]
    private var localSeparatorIndex: Int = 0
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
        if let menuItem = toggleCloudMenuItem, let hotkey = settings.loadToggleCloudHotkey() {
            applyHotkeyToMenuItem(menuItem, hotkey: hotkey)
        }
        if let menuItem = toggleGeminiMenuItem, let hotkey = settings.loadToggleGeminiHotkey() {
            applyHotkeyToMenuItem(menuItem, hotkey: hotkey)
        }
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
            let item = NSMenuItem(
                title: L10n.localModel(model.rawValue),
                action: #selector(handleToggleLocalRecording(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = model.rawValue
            applyHotkeyToMenuItem(item, hotkey: hotkey)
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

        // Add local model items from settings
        let modelSettings = settings.loadWhisperModelSettings()
        for model in WhisperModel.allCases {
            guard let ms = modelSettings[model.rawValue], ms.hotkey != nil else { continue }
            let item = NSMenuItem(
                title: L10n.localModel(model.rawValue),
                action: #selector(handleToggleLocalRecording(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = model.rawValue
            if let hotkey = ms.hotkey {
                applyHotkeyToMenuItem(item, hotkey: hotkey)
            }
            menu.addItem(item)
            localModelMenuItems[model.rawValue] = item
        }

        toggleCloudMenuItem = NSMenuItem(
            title: L10n.cloudRecordingOpenAI,
            action: #selector(handleToggleCloudRecording),
            keyEquivalent: ""
        )
        toggleCloudMenuItem?.target = self
        if let hotkey = settings.loadToggleCloudHotkey() {
            applyHotkeyToMenuItem(toggleCloudMenuItem!, hotkey: hotkey)
        }
        menu.addItem(toggleCloudMenuItem!)

        toggleGeminiMenuItem = NSMenuItem(
            title: L10n.geminiRecording,
            action: #selector(handleToggleGeminiRecording),
            keyEquivalent: ""
        )
        toggleGeminiMenuItem?.target = self
        if let hotkey = settings.loadToggleGeminiHotkey() {
            applyHotkeyToMenuItem(toggleGeminiMenuItem!, hotkey: hotkey)
        }
        menu.addItem(toggleGeminiMenuItem!)

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
