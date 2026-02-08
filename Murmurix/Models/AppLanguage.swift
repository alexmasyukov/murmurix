//
//  AppLanguage.swift
//  Murmurix
//

import Foundation

enum AppLanguage: String, CaseIterable {
    case en
    case ru

    var displayName: String {
        switch self {
        case .en: return "English"
        case .ru: return "Русский"
        }
    }

    static var current: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "en") ?? .en
    }
}

extension Notification.Name {
    static let appLanguageDidChange = Notification.Name("appLanguageDidChange")
}
