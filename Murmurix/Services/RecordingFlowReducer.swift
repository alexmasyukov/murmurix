//
//  RecordingFlowReducer.swift
//  Murmurix
//

import Foundation

enum RecordingFlowEvent: Equatable {
    case toggle(mode: TranscriptionMode)
    case cancelRecording
    case cancelTranscription
}

enum RecordingFlowTransition: Equatable {
    case startRecording(mode: TranscriptionMode)
    case stopRecording
    case cancelRecording
    case cancelTranscription
    case ignore
}

enum RecordingFlowReducer {
    static func reduce(state: RecordingState, event: RecordingFlowEvent) -> RecordingFlowTransition {
        switch (state, event) {
        case (.idle, .toggle(let mode)):
            return .startRecording(mode: mode)
        case (.recording, .toggle):
            return .stopRecording
        case (.recording, .cancelRecording):
            return .cancelRecording
        case (.transcribing, .cancelTranscription):
            return .cancelTranscription
        case (.transcribing, .toggle):
            return .ignore
        default:
            return .ignore
        }
    }
}
