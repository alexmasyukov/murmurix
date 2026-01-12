//
//  MIMETypeResolver.swift
//  Murmurix
//

import Foundation

/// Utility for resolving MIME types from file extensions
enum MIMETypeResolver {

    /// Returns the MIME type for a given file path extension
    /// - Parameter pathExtension: File extension (e.g., "mp3", "wav")
    /// - Returns: MIME type string
    static func mimeType(for pathExtension: String) -> String {
        switch pathExtension.lowercased() {
        case "mp3":
            return "audio/mpeg"
        case "mp4", "m4a":
            return "audio/mp4"
        case "wav":
            return "audio/wav"
        case "webm":
            return "audio/webm"
        case "ogg":
            return "audio/ogg"
        case "flac":
            return "audio/flac"
        case "mpeg", "mpga":
            return "audio/mpeg"
        default:
            return "audio/mpeg"
        }
    }
}
