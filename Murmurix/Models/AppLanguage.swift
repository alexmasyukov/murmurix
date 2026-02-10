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
    static let defaultRawValue = "en"

    var displayName: String {
        switch self {
        case .en: return "English"
        case .ru: return "Русский"
        case .es: return "Español"
        }
    }

    static var current: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? defaultRawValue) ?? .en
    }
}

extension Notification.Name {
    static let appLanguageDidChange = Notification.Name("appLanguageDidChange")
}
