//
//  AppConstants.swift
//  Murmurix
//

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

// MARK: - Network

enum NetworkConfig {
    static let daemonSocketTimeout: Int = 30
    static let daemonStartupTimeout: Int = 50  // iterations of 0.1s = 5s
    static let shutdownTimeout: Int = 5
}

// MARK: - AI

enum AIConfig {
    static let validationMaxTokens: Int = 10
    static let processingMaxTokens: Int = 4096
    static let apiVersion = "2023-06-01"
    static let betaVersion = "structured-outputs-2025-11-13"

    static let defaultPrompt = """
        Ты пост-процессор для голосовых транскрипций.

        Контекст: обсуждение программирования на Golang, Swift, Kotlin, построение архитектуры, системы очередей, фронтенд.

        Задачи:
        1. Замени распознанные названия сервисов, библиотек, фреймворков, инструментов на их оригинальные английские названия
        2. Исправь орфографические ошибки в словах

        Частые замены:
        - "кафка" → "Kafka"
        - "реакт" → "React"
        - "гоуэнг", "голэнг", "го лэнг" → "Golang"
        - "питон" → "Python"
        - "джава скрипт" → "JavaScript"
        - "тайп скрипт" → "TypeScript"
        - "ноуд" → "Node.js"
        - "докер" → "Docker"
        - "кубернетис" → "Kubernetes"
        - "редис" → "Redis"
        - "постгрес" → "PostgreSQL"
        - "монго" → "MongoDB"
        - "гит" → "Git"
        - "гитхаб" → "GitHub"
        - "апи" → "API"
        - "рест" → "REST"
        - "джейсон" → "JSON"
        - "эндпоинт" → "endpoint"
        - "фреймворк" → "framework"
        - "либа", "либы" → "library/libraries"
        - "клауд", "клод" → "Claude"
        - "юз стейт" → "useState"
        - "юз эффект" → "useEffect"
        - "консоль лог" → "console.log"

        Правила:
        1. Сохраняй структуру и смысл текста
        2. Не добавляй ничего лишнего
        """
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
    static let daemonSocket = "daemon.sock"
    static let historyDatabase = "history.sqlite"

    static var expandedApplicationSupport: String {
        NSHomeDirectory() + "/Library/Application Support/Murmurix"
    }

    static var socketPath: String {
        expandedApplicationSupport + "/" + daemonSocket
    }
}
