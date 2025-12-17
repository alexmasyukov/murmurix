//
//  Hotkey.swift
//  Murmurix
//

import Foundation
import Carbon

struct Hotkey: Equatable, Codable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let toggleDefault = Hotkey(keyCode: 2, modifiers: UInt32(controlKey))  // Control+D
    static let cancelDefault = Hotkey(keyCode: 53, modifiers: 0)  // Escape

    var displayParts: [String] {
        var parts: [String] = []

        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }

        if let keyName = Self.keyCodeToName(keyCode) {
            parts.append(keyName)
        }

        return parts.isEmpty ? ["Not set"] : parts
    }

    static func keyCodeToName(_ code: UInt32) -> String? {
        let keyMap: [UInt32: String] = [
            // Letters
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P", 37: "L",
            38: "J", 40: "K", 45: "N", 46: "M",
            // Numbers
            18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5",
            25: "9", 26: "7", 28: "8", 29: "0",
            // Symbols
            24: "=", 27: "-", 30: "]", 33: "[", 39: "'", 41: ";",
            42: "\\", 43: ",", 44: "/", 47: ".", 50: "`",
            // Control keys
            36: "↩", 48: "⇥", 49: "␣", 51: "⌫", 53: "esc",
            71: "⌧", 76: "⌅",  // Clear, Enter (numpad)
            // Navigation
            115: "↖", 116: "⇞", 117: "⌦", 119: "↘", 121: "⇟",  // Home, PageUp, Delete, End, PageDown
            123: "←", 124: "→", 125: "↓", 126: "↑",
            // Function keys F1-F12
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5",
            97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10",
            103: "F11", 111: "F12",
            // Function keys F13-F20
            105: "F13", 107: "F14", 113: "F15", 106: "F16",
            64: "F17", 79: "F18", 80: "F19", 90: "F20",
            // Numpad
            65: ".", 67: "*", 69: "+", 75: "/", 78: "-",
            81: "=", 82: "0", 83: "1", 84: "2", 85: "3",
            86: "4", 87: "5", 88: "6", 89: "7", 91: "8", 92: "9"
        ]
        return keyMap[code]
    }
}
