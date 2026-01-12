//
//  MenuBarManager.swift
//  Murmurix
//

import AppKit
import Carbon

protocol MenuBarManagerDelegate: AnyObject {
    func menuBarDidRequestToggleLocalRecording()
    func menuBarDidRequestToggleCloudRecording()
    func menuBarDidRequestOpenHistory()
    func menuBarDidRequestOpenSettings()
    func menuBarDidRequestQuit()
}

final class MenuBarManager {
    weak var delegate: MenuBarManagerDelegate?

    private var statusItem: NSStatusItem!
    private var toggleLocalMenuItem: NSMenuItem?
    private var toggleCloudMenuItem: NSMenuItem?
    private let settings: SettingsStorageProtocol

    init(settings: SettingsStorageProtocol = Settings.shared) {
        self.settings = settings
    }

    func setup() {
        setupStatusItem()
        setupMenu()
    }

    func updateHotkeyDisplay() {
        if let menuItem = toggleLocalMenuItem {
            applyHotkeyToMenuItem(menuItem, hotkey: settings.loadToggleLocalHotkey())
        }
        if let menuItem = toggleCloudMenuItem {
            applyHotkeyToMenuItem(menuItem, hotkey: settings.loadToggleCloudHotkey())
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
        let menu = NSMenu()

        toggleLocalMenuItem = NSMenuItem(
            title: "Local Recording (Whisper)",
            action: #selector(handleToggleLocalRecording),
            keyEquivalent: ""
        )
        toggleLocalMenuItem?.target = self
        applyHotkeyToMenuItem(toggleLocalMenuItem!, hotkey: settings.loadToggleLocalHotkey())
        menu.addItem(toggleLocalMenuItem!)

        toggleCloudMenuItem = NSMenuItem(
            title: "Cloud Recording (OpenAI)",
            action: #selector(handleToggleCloudRecording),
            keyEquivalent: ""
        )
        toggleCloudMenuItem?.target = self
        applyHotkeyToMenuItem(toggleCloudMenuItem!, hotkey: settings.loadToggleCloudHotkey())
        menu.addItem(toggleCloudMenuItem!)

        menu.addItem(NSMenuItem.separator())

        let historyItem = NSMenuItem(
            title: "History...",
            action: #selector(handleOpenHistory),
            keyEquivalent: "h"
        )
        historyItem.target = self
        menu.addItem(historyItem)

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(handleOpenSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit",
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

    @objc private func handleToggleLocalRecording() {
        delegate?.menuBarDidRequestToggleLocalRecording()
    }

    @objc private func handleToggleCloudRecording() {
        delegate?.menuBarDidRequestToggleCloudRecording()
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
