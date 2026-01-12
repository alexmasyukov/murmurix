//
//  GeminiTranscriptionModel.swift
//  Murmurix
//

import Foundation

enum GeminiTranscriptionModel: String, CaseIterable {
    case flash2 = "gemini-2.0-flash"
    case flash = "gemini-1.5-flash"
    case pro = "gemini-1.5-pro"

    var displayName: String {
        switch self {
        case .flash2:
            return "Gemini 2.0 Flash (recommended)"
        case .flash:
            return "Gemini 1.5 Flash"
        case .pro:
            return "Gemini 1.5 Pro (best quality)"
        }
    }

    var description: String {
        switch self {
        case .flash2:
            return "Fast and efficient, best for voice transcription"
        case .flash:
            return "Previous generation, stable"
        case .pro:
            return "Best accuracy for complex audio"
        }
    }
}
