//
//  OpenAITranscriptionModel.swift
//  Murmurix
//

import Foundation

enum OpenAITranscriptionModel: String, CaseIterable {
    case gpt4oTranscribe = "gpt-4o-transcribe"
    case gpt4oMiniTranscribe = "gpt-4o-mini-transcribe"

    var displayName: String {
        switch self {
        case .gpt4oTranscribe:
            return "GPT-4o Transcribe (best)"
        case .gpt4oMiniTranscribe:
            return "GPT-4o Mini (faster)"
        }
    }
}
