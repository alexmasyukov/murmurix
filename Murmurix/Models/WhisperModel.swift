//
//  WhisperModel.swift
//  Murmurix
//

import Foundation

enum WhisperModel: String, CaseIterable {
    case tiny = "tiny"
    case base = "base"
    case small = "small"
    case medium = "medium"
    case largeV2 = "large-v2"
    case largeV3 = "large-v3"

    var displayName: String {
        switch self {
        case .tiny: return "Tiny (fastest, ~75MB)"
        case .base: return "Base (~140MB)"
        case .small: return "Small (~460MB)"
        case .medium: return "Medium (~1.5GB)"
        case .largeV2: return "Large v2 (~3GB)"
        case .largeV3: return "Large v3 (best, ~3GB)"
        }
    }

    var isInstalled: Bool {
        let hfCache = NSHomeDirectory() + "/.cache/huggingface/hub/models--Systran--faster-whisper-\(rawValue)"
        let snapshotsPath = hfCache + "/snapshots"

        guard FileManager.default.fileExists(atPath: snapshotsPath),
              let snapshots = try? FileManager.default.contentsOfDirectory(atPath: snapshotsPath) else {
            return false
        }

        for snapshot in snapshots {
            let modelBin = snapshotsPath + "/\(snapshot)/model.bin"
            let configJson = snapshotsPath + "/\(snapshot)/config.json"
            if FileManager.default.fileExists(atPath: modelBin) || FileManager.default.fileExists(atPath: configJson) {
                return true
            }
        }
        return false
    }

    static var installedModels: [WhisperModel] {
        allCases.filter { $0.isInstalled }
    }
}
