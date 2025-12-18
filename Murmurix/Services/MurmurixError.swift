//
//  MurmurixError.swift
//  Murmurix
//

import Foundation

/// Unified error type for Murmurix application
enum MurmurixError: LocalizedError {
    case transcription(TranscriptionError)
    case ai(AIError)
    case daemon(DaemonError)
    case system(SystemError)

    var errorDescription: String? {
        switch self {
        case .transcription(let error): return error.errorDescription
        case .ai(let error): return error.errorDescription
        case .daemon(let error): return error.errorDescription
        case .system(let error): return error.errorDescription
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .transcription(let error): return error.recoverySuggestion
        case .ai(let error): return error.recoverySuggestion
        case .daemon(let error): return error.recoverySuggestion
        case .system(let error): return error.recoverySuggestion
        }
    }
}

// MARK: - Transcription Errors

enum TranscriptionError: LocalizedError {
    case pythonNotFound
    case scriptNotFound
    case daemonNotRunning
    case failed(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .pythonNotFound:
            return "Python not found"
        case .scriptNotFound:
            return "Transcription script not found"
        case .daemonNotRunning:
            return "Transcription daemon is not running"
        case .failed(let message):
            return "Transcription failed: \(message)"
        case .timeout:
            return "Transcription timed out"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .pythonNotFound:
            return "Please install Python 3.11 or later"
        case .scriptNotFound:
            return "Reinstall the application or check ~/Library/Application Support/Murmurix/"
        case .daemonNotRunning:
            return "Enable 'Keep model in memory' in Settings"
        case .failed:
            return "Try recording again"
        case .timeout:
            return "The transcription took too long. Try a shorter recording"
        }
    }
}

// MARK: - AI Errors

enum AIError: LocalizedError {
    case noApiKey
    case invalidApiKey
    case invalidResponse
    case apiError(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .noApiKey:
            return "Claude API key not configured"
        case .invalidApiKey:
            return "Invalid API key"
        case .invalidResponse:
            return "Invalid response from Claude API"
        case .apiError(let message):
            return "Claude API error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noApiKey:
            return "Add your Claude API key in Settings → AI Processing"
        case .invalidApiKey:
            return "Check your API key in Settings → AI Processing"
        case .invalidResponse:
            return "Try again later"
        case .apiError:
            return "Check your API key or try again later"
        case .networkError:
            return "Check your internet connection"
        }
    }
}

// MARK: - Daemon Errors

enum DaemonError: LocalizedError {
    case notRunning
    case startFailed(String)
    case communicationFailed

    var errorDescription: String? {
        switch self {
        case .notRunning:
            return "Daemon is not running"
        case .startFailed(let reason):
            return "Failed to start daemon: \(reason)"
        case .communicationFailed:
            return "Failed to communicate with daemon"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notRunning:
            return "Enable 'Keep model in memory' in Settings"
        case .startFailed:
            return "Check Python installation and available disk space"
        case .communicationFailed:
            return "Try restarting the application"
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
