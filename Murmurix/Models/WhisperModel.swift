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
        let fm = FileManager.default
        let modelDir = ModelPaths.modelDir(for: rawValue)

        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: modelDir.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }

        // Check that the folder contains at least one .mlmodelc directory
        if let contents = try? fm.contentsOfDirectory(atPath: modelDir.path) {
            return contents.contains { $0.hasSuffix(".mlmodelc") }
        }
        return false
    }

    static var installedModels: [WhisperModel] {
        allCases.filter { $0.isInstalled }
    }
}
