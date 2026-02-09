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
        removeFileIfExists(outputURL, context: "prepare compression output")

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
            if let originalSize = fileSize(at: sourceURL),
               let compressedSize = fileSize(at: outputURL),
               compressedSize > 0 {
                let ratio = Double(originalSize) / Double(compressedSize)
                Logger.Audio.info("Compression ratio: \(String(format: "%.1fx", ratio)) (\(originalSize/1024)KB -> \(compressedSize/1024)KB)")
            }

            // Delete original if requested
            if deleteOriginal {
                removeFileIfExists(sourceURL, context: "delete original after compression")
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

    private static func fileSize(at url: URL) -> Int? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int
        } catch {
            Logger.Audio.debug("Failed to read file size at \(url.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
    }

    private static func removeFileIfExists(_ url: URL, context: String) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else { return }

        do {
            try fileManager.removeItem(at: url)
        } catch {
            Logger.Audio.error("Failed to remove file during \(context): \(url.path), error: \(error.localizedDescription)")
        }
    }
}
