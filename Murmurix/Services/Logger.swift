//
//  Logger.swift
//  Murmurix
//

import Foundation
import os.log

/// Centralized logging utility using os.log for system integration
enum Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.murmurix"

    private static let audio = OSLog(subsystem: subsystem, category: "Audio")
    private static let transcription = OSLog(subsystem: subsystem, category: "Transcription")
    private static let model = OSLog(subsystem: subsystem, category: "Model")
    private static let hotkey = OSLog(subsystem: subsystem, category: "Hotkey")
    private static let history = OSLog(subsystem: subsystem, category: "History")
    private static let settings = OSLog(subsystem: subsystem, category: "Settings")

    private static func logInfo(_ message: String, to log: OSLog) {
        os_log(.info, log: log, "%{public}@", message)
    }

    private static func logError(_ message: String, to log: OSLog) {
        os_log(.error, log: log, "%{public}@", message)
    }

    private static func logDebug(_ message: String, to log: OSLog) {
        os_log(.debug, log: log, "%{public}@", message)
    }

    // MARK: - Audio

    enum Audio {
        static func info(_ message: String) {
            Logger.logInfo(message, to: Logger.audio)
        }

        static func error(_ message: String) {
            Logger.logError(message, to: Logger.audio)
        }

        static func debug(_ message: String) {
            Logger.logDebug(message, to: Logger.audio)
        }
    }

    // MARK: - Transcription

    enum Transcription {
        static func info(_ message: String) {
            Logger.logInfo(message, to: Logger.transcription)
        }

        static func error(_ message: String) {
            Logger.logError(message, to: Logger.transcription)
        }

        static func debug(_ message: String) {
            Logger.logDebug(message, to: Logger.transcription)
        }
    }

    // MARK: - Model

    enum Model {
        static func info(_ message: String) {
            Logger.logInfo(message, to: Logger.model)
        }

        static func error(_ message: String) {
            Logger.logError(message, to: Logger.model)
        }

        static func warning(_ message: String) {
            os_log(.default, log: Logger.model, "%{public}@", message)
        }

        static func debug(_ message: String) {
            Logger.logDebug(message, to: Logger.model)
        }
    }

    // MARK: - Hotkey

    enum Hotkey {
        static func info(_ message: String) {
            Logger.logInfo(message, to: Logger.hotkey)
        }

        static func error(_ message: String) {
            Logger.logError(message, to: Logger.hotkey)
        }
    }

    // MARK: - History

    enum History {
        static func error(_ message: String) {
            Logger.logError(message, to: Logger.history)
        }

        static func debug(_ message: String) {
            Logger.logDebug(message, to: Logger.history)
        }
    }

    // MARK: - Settings

    enum Settings {
        static func debug(_ message: String) {
            Logger.logDebug(message, to: Logger.settings)
        }
    }

}
