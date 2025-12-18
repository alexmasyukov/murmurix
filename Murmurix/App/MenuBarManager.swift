//
//  MenuBarManager.swift
//  Murmurix
//

import AppKit
import Carbon

protocol MenuBarManagerDelegate: AnyObject {
    func menuBarDidRequestToggleRecording()
    func menuBarDidRequestOpenHistory()
    func menuBarDidRequestOpenSettings()
    func menuBarDidRequestQuit()
}

final class MenuBarManager {
    weak var delegate: MenuBarManagerDelegate?

    private var statusItem: NSStatusItem!
    private var toggleMenuItem: NSMenuItem?
    private let settings: SettingsStorageProtocol

    init(settings: SettingsStorageProtocol = Settings.shared) {
        self.settings = settings
    }

    func setup() {
        setupStatusItem()
        setupMenu()
    }

    func updateHotkeyDisplay() {
        guard let menuItem = toggleMenuItem else { return }
        applyHotkeyToMenuItem(menuItem)
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

        toggleMenuItem = NSMenuItem(
            title: "Toggle Recording",
            action: #selector(handleToggleRecording),
            keyEquivalent: ""
        )
        toggleMenuItem?.target = self
        applyHotkeyToMenuItem(toggleMenuItem!)
        menu.addItem(toggleMenuItem!)

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

    private func applyHotkeyToMenuItem(_ menuItem: NSMenuItem) {
        let hotkey = settings.loadToggleHotkey()

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

    @objc private func handleToggleRecording() {
        delegate?.menuBarDidRequestToggleRecording()
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
