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

    var shortName: String {
        switch self {
        case .tiny: return "Tiny"
        case .base: return "Base"
        case .small: return "Small"
        case .medium: return "Medium"
        case .largeV2: return "Large v2"
        case .largeV3: return "Large v3"
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
