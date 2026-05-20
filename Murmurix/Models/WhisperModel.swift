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
    case largeV2Turbo = "large-v2_turbo"
    case largeV2TurboCompressed = "large-v2_turbo_955MB"
    case largeV3Turbo = "large-v3_turbo"
    case largeV3TurboCompressed = "large-v3_turbo_954MB"
    case largeV3TurboV20240930 = "large-v3-v20240930_turbo"
    case largeV3TurboV20240930Compressed = "large-v3-v20240930_turbo_632MB"

    var shortName: String {
        switch self {
        case .tiny: return "Tiny"
        case .base: return "Base"
        case .small: return "Small"
        case .medium: return "Medium"
        case .largeV2: return "Large v2"
        case .largeV3: return "Large v3"
        case .largeV2Turbo: return "Large v2 Turbo"
        case .largeV2TurboCompressed: return "Large v2 Turbo (955 MB)"
        case .largeV3Turbo: return "Large v3 Turbo"
        case .largeV3TurboCompressed: return "Large v3 Turbo (954 MB)"
        case .largeV3TurboV20240930: return "Large v3 Turbo 2024-09-30"
        case .largeV3TurboV20240930Compressed: return "Large v3 Turbo 2024-09-30 (632 MB)"
        }
    }

    var isInstalled: Bool {
        let fm = FileManager.default
        let modelDir = ModelPaths.modelDir(for: rawValue)

        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: modelDir.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }

        // Check that the folder contains at least one .mlmodelc directory
        do {
            let contents = try fm.contentsOfDirectory(atPath: modelDir.path)
            return contents.contains { $0.hasSuffix(".mlmodelc") }
        } catch {
            Logger.Model.debug("Failed to inspect model directory \(modelDir.path): \(error.localizedDescription)")
            return false
        }
    }

    static var installedModels: [WhisperModel] {
        allCases.filter { $0.isInstalled }
    }
}
