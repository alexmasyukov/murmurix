//
//  AppLanguage.swift
//  Murmurix
//

import Foundation

enum AppLanguage: String, CaseIterable {
    case en
    case ru
    case es

    static let storageKey = "appLanguage"
    static let defaultValue: AppLanguage = .en
    static let defaultRawValue = defaultValue.rawValue

    static func normalized(from rawValue: String) -> AppLanguage {
        AppLanguage(rawValue: rawValue) ?? defaultValue
    }

    static func normalizedRawValue(from rawValue: String) -> String {
        normalized(from: rawValue).rawValue
    }

    var displayName: String {
        switch self {
        case .en: return "English"
        case .ru: return "Русский"
        case .es: return "Español"
        }
    }

    static func current(in defaults: UserDefaults) -> AppLanguage {
        guard let rawValue = defaults.string(forKey: storageKey) else {
            return defaultValue
        }
        return normalized(from: rawValue)
    }

    static var current: AppLanguage {
        current(in: .standard)
    }

    static func postDidChange(on center: NotificationCenter = .default) {
        center.post(name: .appLanguageDidChange, object: nil)
    }
}

extension Notification.Name {
    static let appLanguageDidChange = Notification.Name("appLanguageDidChange")
}
