//
//  AIModel.swift
//  Murmurix
//

import Foundation

enum AIModel: String, CaseIterable {
    case haiku = "claude-haiku-4-5"
    case sonnet = "claude-sonnet-4-5"
    case opus = "claude-opus-4-5"

    var displayName: String {
        switch self {
        case .haiku: return "Haiku 4.5 (Fast)"
        case .sonnet: return "Sonnet 4.5"
        case .opus: return "Opus 4.5 (Best)"
        }
    }
}
