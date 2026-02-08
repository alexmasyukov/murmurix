//
//  MurmurixError.swift
//  Murmurix
//

import Foundation

/// Unified error type for Murmurix application
enum MurmurixError: LocalizedError {
    case transcription(TranscriptionError)
    case model(ModelError)
    case system(SystemError)

    var errorDescription: String? {
        switch self {
        case .transcription(let error): return error.errorDescription
        case .model(let error): return error.errorDescription
        case .system(let error): return error.errorDescription
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .transcription(let error): return error.recoverySuggestion
        case .model(let error): return error.recoverySuggestion
        case .system(let error): return error.recoverySuggestion
        }
    }
}

// MARK: - Transcription Errors

enum TranscriptionError: LocalizedError {
    case modelNotLoaded
    case failed(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Whisper model is not loaded"
        case .failed(let message):
            return "Transcription failed: \(message)"
        case .timeout:
            return "Transcription timed out"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .modelNotLoaded:
            return "Enable 'Keep model loaded' in Settings"
        case .failed:
            return "Try recording again"
        case .timeout:
            return "The transcription took too long. Try a shorter recording"
        }
    }
}

// MARK: - Model Errors

enum ModelError: LocalizedError {
    case downloadFailed(String)
    case loadFailed(String)
    case notFound(String)

    var errorDescription: String? {
        switch self {
        case .downloadFailed(let reason):
            return "Model download failed: \(reason)"
        case .loadFailed(let reason):
            return "Failed to load model: \(reason)"
        case .notFound(let name):
            return "Model not found: \(name)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .downloadFailed:
            return "Check your internet connection and try again"
        case .loadFailed:
            return "Try restarting the application"
        case .notFound:
            return "Download the model from Settings"
        }
    }
}

// MARK: - System Errors

enum SystemError: LocalizedError {
    case microphonePermissionDenied
    case accessibilityPermissionDenied
    case fileNotFound(String)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access denied"
        case .accessibilityPermissionDenied:
            return "Accessibility access denied"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .unknown(let error):
            return error.localizedDescription
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Enable microphone access in System Settings → Privacy → Microphone"
        case .accessibilityPermissionDenied:
            return "Enable accessibility in System Settings → Privacy → Accessibility"
        case .fileNotFound:
            return "Reinstall the application"
        case .unknown:
            return "Try restarting the application"
        }
    }
}
