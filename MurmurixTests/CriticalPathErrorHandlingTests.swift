import Testing
import Foundation

struct CriticalPathErrorHandlingTests {
    @Test func criticalCleanupAndCompressionPathsContainNoSilentTry() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // MurmurixTests
            .deletingLastPathComponent() // project root

        let criticalFiles = [
            "Murmurix/Services/RecordingCoordinator.swift",
            "Murmurix/Services/AudioCompressor.swift"
        ]

        for relativePath in criticalFiles {
            let fileURL = projectRoot.appendingPathComponent(relativePath)
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            #expect(!source.contains("try?"), "\(relativePath) should not contain silent try?")
        }
    }
}
