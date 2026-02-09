//
//  AppConstants.swift
//  Murmurix
//

import Foundation
import SwiftUI

// MARK: - Layout

enum Layout {
    enum Padding {
        static let standard: CGFloat = 16
        static let small: CGFloat = 8
        static let vertical: CGFloat = 10
        static let section: CGFloat = 20
    }

    enum CornerRadius {
        static let card: CGFloat = 10
        static let button: CGFloat = 6
        static let window: CGFloat = 16
    }

    enum Spacing {
        static let section: CGFloat = 12
        static let item: CGFloat = 8
        static let tiny: CGFloat = 2
        static let indicator: CGFloat = 6
    }
}

// MARK: - Typography

enum Typography {
    static let title: Font = .system(size: 14, weight: .medium)
    static let label: Font = .system(size: 13)
    static let description: Font = .system(size: 11)
    static let caption: Font = .system(size: 10)
    static let monospaced: Font = .system(size: 12, design: .monospaced)
}

// MARK: - Colors

enum AppColors {
    static let backgroundOpacity: Double = 0.05
    static let borderOpacity: Double = 0.1
    static let disabledOpacity: Double = 0.5
    static let mutedOpacity: Double = 0.6

    static let cardBackground = Color.white.opacity(backgroundOpacity)
    static let divider = Color.white.opacity(borderOpacity)

    // Button and control backgrounds
    static let buttonBackground = Color.white.opacity(0.15)
    static let buttonBackgroundSubtle = Color.white.opacity(0.08)
    static let subtleBorder = Color.white.opacity(0.2)
    static let statsBackground = Color.white.opacity(0.1)

    // Overlay backgrounds
    static let overlayBackground = Color.black.opacity(0.9)
    static let overlayBackgroundLight = Color.black.opacity(0.3)

    // Interactive elements
    static let circleButtonBackground = Color.white.opacity(0.2)
}

// MARK: - Audio

enum AudioConfig {
    static let voiceActivityThreshold: Float = 0.33
    static let meterUpdateInterval: TimeInterval = 0.05
    static let sampleRate: Double = 16000.0
}

// MARK: - Window Sizes

enum WindowSize {
    static let recording = NSSize(width: 140, height: 48)
    static let result = NSSize(width: 420, height: 300)
    static let settings = NSSize(width: 500, height: 450)
    static let history = NSSize(width: 600, height: 400)
}

// MARK: - App Paths

enum AppPaths {
    static let applicationSupport = "~/Library/Application Support/Murmurix"
    static let historyDatabase = "history.sqlite"

    static var expandedApplicationSupport: String {
        NSHomeDirectory() + "/Library/Application Support/Murmurix"
    }
}

// MARK: - Defaults

enum Defaults {
    static let language = "ru"
}

// MARK: - Model Paths

enum ModelPaths {
    static let repoSubpath = "huggingface/models/argmaxinc/whisperkit-coreml"
    static let customRepoDirEnv = "MURMURIX_MODEL_REPO_DIR"
    static let useTempRepoEnv = "MURMURIX_USE_TEMP_MODEL_REPO"
    static let debugRepoRoot = "murmurix-dev-models"

    private static var tempRepoDir: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(debugRepoRoot)
            .appendingPathComponent(repoSubpath)
    }

    static var repoDir: URL {
        let environment = ProcessInfo.processInfo.environment

        if let customPath = environment[customRepoDirEnv], !customPath.isEmpty {
            return URL(fileURLWithPath: customPath).standardizedFileURL
        }

        if environment[useTempRepoEnv] == "1" {
            return tempRepoDir
        }

#if DEBUG
        if environment[useTempRepoEnv] != "0" {
            return tempRepoDir
        }
#endif

        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
        return documentsDir.appendingPathComponent(repoSubpath)
    }

    static var downloadBaseDir: URL {
        // HubApi expects a base path and appends "models/argmaxinc/whisperkit-coreml".
        repoDir
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    static func modelDir(for name: String) -> URL {
        repoDir.appendingPathComponent("openai_whisper-\(name)")
    }
}
