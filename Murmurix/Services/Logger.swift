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
    private static let daemon = OSLog(subsystem: subsystem, category: "Daemon")
    private static let hotkey = OSLog(subsystem: subsystem, category: "Hotkey")
    private static let history = OSLog(subsystem: subsystem, category: "History")

    // MARK: - Audio

    enum Audio {
        static func info(_ message: String) {
            os_log(.info, log: Logger.audio, "%{public}@", message)
        }

        static func error(_ message: String) {
            os_log(.error, log: Logger.audio, "%{public}@", message)
        }

        static func debug(_ message: String) {
            os_log(.debug, log: Logger.audio, "%{public}@", message)
        }
    }

    // MARK: - Transcription

    enum Transcription {
        static func info(_ message: String) {
            os_log(.info, log: Logger.transcription, "%{public}@", message)
        }

        static func error(_ message: String) {
            os_log(.error, log: Logger.transcription, "%{public}@", message)
        }

        static func debug(_ message: String) {
            os_log(.debug, log: Logger.transcription, "%{public}@", message)
        }
    }

    // MARK: - Daemon

    enum Daemon {
        static func info(_ message: String) {
            os_log(.info, log: Logger.daemon, "%{public}@", message)
        }

        static func error(_ message: String) {
            os_log(.error, log: Logger.daemon, "%{public}@", message)
        }

        static func warning(_ message: String) {
            os_log(.default, log: Logger.daemon, "%{public}@", message)
        }

        static func debug(_ message: String) {
            os_log(.debug, log: Logger.daemon, "%{public}@", message)
        }
    }

    // MARK: - Hotkey

    enum Hotkey {
        static func info(_ message: String) {
            os_log(.info, log: Logger.hotkey, "%{public}@", message)
        }

        static func error(_ message: String) {
            os_log(.error, log: Logger.hotkey, "%{public}@", message)
        }
    }

    // MARK: - History

    enum History {
        static func error(_ message: String) {
            os_log(.error, log: Logger.history, "%{public}@", message)
        }

        static func debug(_ message: String) {
            os_log(.debug, log: Logger.history, "%{public}@", message)
        }
    }

}
