//
//  TranscriptionRecord.swift
//  Murmurix
//

import Foundation

struct TranscriptionRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    let language: String
    let duration: TimeInterval // recording duration in seconds
    let createdAt: Date

    init(id: UUID = UUID(), text: String, language: String, duration: TimeInterval, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.language = language
        self.duration = duration
        self.createdAt = createdAt
    }

    var shortText: String {
        let maxLength = 50
        if text.count <= maxLength {
            return text
        }
        return String(text.prefix(maxLength)) + "..."
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
