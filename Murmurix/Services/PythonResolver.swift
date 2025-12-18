//
//  PythonResolver.swift
//  Murmurix
//

import Foundation

enum PythonResolver {
    private static let pythonPaths = [
        "/usr/local/bin/python3",
        "/opt/homebrew/bin/python3",
        "/Library/Frameworks/Python.framework/Versions/3.12/bin/python3",
        "/Library/Frameworks/Python.framework/Versions/3.11/bin/python3",
        "/usr/bin/python3"
    ]

    static func findPython() -> String? {
        pythonPaths.first { FileManager.default.fileExists(atPath: $0) }
    }

    static func findScript(named scriptName: String) -> String? {
        let paths = [
            NSHomeDirectory() + "/Library/Application Support/Murmurix/\(scriptName).py",
            Bundle.main.path(forResource: scriptName, ofType: "py"),
            NSHomeDirectory() + "/Swift/Murmurix/Python/\(scriptName).py"
        ].compactMap { $0 }

        return paths.first { FileManager.default.fileExists(atPath: $0) }
    }

    static func findTranscribeScript() -> String? {
        findScript(named: "transcribe")
    }

    static func findDaemonScript() -> String? {
        findScript(named: "transcribe_daemon")
    }
}
