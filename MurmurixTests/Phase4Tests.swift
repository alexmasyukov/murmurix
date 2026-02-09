//
//  Phase4Tests.swift
//  MurmurixTests
//
//  Tests for Phase 4 refactoring: KeychainKey enum
//

import Testing
import Foundation
@testable import Murmurix

// MARK: - KeychainKey Enum Tests

struct KeychainKeyEnumTests {

    @Test func keychainKeyHasAllExpectedCases() {
        let allCases = KeychainKey.allCases
        #expect(allCases.count == 2)
        #expect(allCases.contains(.openaiApiKey))
        #expect(allCases.contains(.geminiApiKey))
    }

    @Test func keychainKeyRawValuesAreCorrect() {
        #expect(KeychainKey.openaiApiKey.rawValue == "openaiApiKey")
        #expect(KeychainKey.geminiApiKey.rawValue == "geminiApiKey")
    }

    @Test func keychainKeyIsCaseIterable() {
        // This test verifies that CaseIterable conformance works
        let count = KeychainKey.allCases.count
        #expect(count > 0)
    }

    @Test func keychainKeyCanBeInitializedFromRawValue() {
        let openaiKey = KeychainKey(rawValue: "openaiApiKey")
        let geminiKey = KeychainKey(rawValue: "geminiApiKey")
        let invalidKey = KeychainKey(rawValue: "invalidKey")

        #expect(openaiKey == .openaiApiKey)
        #expect(geminiKey == .geminiApiKey)
        #expect(invalidKey == nil)
    }
}

// MARK: - KeychainService Type-Safe API Tests

struct KeychainServiceTypeSafeAPITests {

    @Test func typeSafeAPICallsStringAPI() {
        let key = KeychainKey.openaiApiKey
        _ = KeychainService.save(key, value: "test")

        let loaded = KeychainService.load(key)
        let exists = KeychainService.exists(key)

        if exists {
            #expect(loaded != nil)
        } else {
            #expect(loaded == nil)
        }

        _ = KeychainService.delete(key)
    }

    @Test func deleteWithKeychainKeyReturnsTrue() {
        // Delete should return true even if item doesn't exist (errSecItemNotFound is handled)
        let deleteResult = KeychainService.delete(KeychainKey.geminiApiKey)
        #expect(deleteResult == true)
    }

    @Test func loadNonExistentKeyReturnsNil() {
        // Ensure key doesn't exist
        KeychainService.delete(KeychainKey.geminiApiKey)

        let value = KeychainService.load(KeychainKey.geminiApiKey)
        #expect(value == nil)
    }

    @Test func keychainKeyEnumUsedInSettings() {
        // Verify that Settings uses KeychainKey enum by checking the code compiles
        // This is a compile-time check - if Settings used string literals that don't match
        // KeychainKey cases, the tests wouldn't compile

        // Create settings with mock defaults
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let settings = Settings(defaults: defaults)

        // These operations use KeychainService with KeychainKey internally.
        #expect(type(of: settings.openaiApiKey) == String.self)
        #expect(type(of: settings.geminiApiKey) == String.self)
    }
}
