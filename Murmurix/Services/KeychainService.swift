//
//  KeychainService.swift
//  Murmurix
//

import Foundation
import Security

/// Keys for storing sensitive data in Keychain
enum KeychainKey: String, CaseIterable {
    case openaiApiKey = "openaiApiKey"
    case geminiApiKey = "geminiApiKey"
}

final class KeychainService {
    private static let serviceName = "com.murmurix.app"

    enum KeychainError: Error {
        case duplicateEntry
        case unknown(OSStatus)
        case itemNotFound
        case invalidData
    }

    // MARK: - Type-safe API (preferred)

    /// Save a string value to Keychain using type-safe key
    @discardableResult
    static func save(_ key: KeychainKey, value: String) -> Bool {
        save(key: key.rawValue, value: value)
    }

    /// Load a string value from Keychain using type-safe key
    static func load(_ key: KeychainKey) -> String? {
        load(key: key.rawValue)
    }

    /// Delete a value from Keychain using type-safe key
    @discardableResult
    static func delete(_ key: KeychainKey) -> Bool {
        delete(key: key.rawValue)
    }

    /// Check if a key exists in Keychain using type-safe key
    static func exists(_ key: KeychainKey) -> Bool {
        exists(key: key.rawValue)
    }

    // MARK: - String-based API (internal)

    /// Save a string value to Keychain
    @discardableResult
    static func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        // Delete existing item first
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Load a string value from Keychain
    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    /// Delete a value from Keychain
    @discardableResult
    static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Check if a key exists in Keychain
    static func exists(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: false
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}
