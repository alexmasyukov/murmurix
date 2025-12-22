//
//  AudioCompressor.swift
//  Murmurix
//

import Foundation
import AVFoundation

/// Compresses WAV audio files to M4A (AAC) format for efficient network transfer
final class AudioCompressor {

    enum CompressionError: LocalizedError {
        case exportFailed(String)
        case assetLoadFailed
        case exportSessionCreationFailed

        var errorDescription: String? {
            switch self {
            case .exportFailed(let reason):
                return "Audio compression failed: \(reason)"
            case .assetLoadFailed:
                return "Failed to load audio file"
            case .exportSessionCreationFailed:
                return "Failed to create export session"
            }
        }
    }

    /// Compresses a WAV file to M4A (AAC) format
    /// - Parameters:
    ///   - sourceURL: Path to the source WAV file
    ///   - deleteOriginal: Whether to delete the original WAV file after compression
    /// - Returns: URL to the compressed M4A file
    static func compress(wavURL sourceURL: URL, deleteOriginal: Bool = false) async throws -> URL {
        let asset = AVAsset(url: sourceURL)

        // Check if asset is valid
        guard try await asset.load(.isPlayable) else {
            throw CompressionError.assetLoadFailed
        }

        // Create output URL with .m4a extension
        let outputURL = sourceURL.deletingPathExtension().appendingPathExtension("m4a")

        // Remove existing file if present
        try? FileManager.default.removeItem(at: outputURL)

        // Create export session
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw CompressionError.exportSessionCreationFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        // Export
        await exportSession.export()

        switch exportSession.status {
        case .completed:
            Logger.Audio.info("Compressed audio: \(sourceURL.lastPathComponent) -> \(outputURL.lastPathComponent)")

            // Log size reduction
            if let originalSize = try? FileManager.default.attributesOfItem(atPath: sourceURL.path)[.size] as? Int,
               let compressedSize = try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int {
                let ratio = Double(originalSize) / Double(compressedSize)
                Logger.Audio.info("Compression ratio: \(String(format: "%.1fx", ratio)) (\(originalSize/1024)KB -> \(compressedSize/1024)KB)")
            }

            // Delete original if requested
            if deleteOriginal {
                try? FileManager.default.removeItem(at: sourceURL)
            }

            return outputURL

        case .failed:
            let errorMessage = exportSession.error?.localizedDescription ?? "Unknown error"
            throw CompressionError.exportFailed(errorMessage)

        case .cancelled:
            throw CompressionError.exportFailed("Export was cancelled")

        default:
            throw CompressionError.exportFailed("Unexpected export status: \(exportSession.status.rawValue)")
        }
    }
}
