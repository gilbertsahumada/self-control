import Foundation

enum PrivilegedExecutor {
    enum ExecutionError: LocalizedError {
        case scriptCreationFailed
        case executionFailed(String)
        case userCancelled

        var errorDescription: String? {
            switch self {
            case .scriptCreationFailed:
                return "Failed to create AppleScript"
            case .executionFailed(let message):
                return "Execution failed: \(message)"
            case .userCancelled:
                return "User cancelled the operation"
            }
        }
    }

    static func run(_ shellScript: String) throws {
        let tempDir = FileManager.default.temporaryDirectory
        
        let scriptPath = tempDir.appendingPathComponent("blocksites_script_\(UUID().uuidString).sh")
        try shellScript.write(to: scriptPath, atomically: true, encoding: .utf8)
        
        defer {
            try? FileManager.default.removeItem(at: scriptPath)
        }

        let escapedScriptPath = scriptPath.path
            .replacingOccurrences(of: "'", with: "'\\''")

        let source = "do shell script \"bash '\(escapedScriptPath)'\" with administrator privileges"

        guard let script = NSAppleScript(source: source) else {
            throw ExecutionError.scriptCreationFailed
        }

        var errorDict: NSDictionary?
        script.executeAndReturnError(&errorDict)

        if let error = errorDict {
            let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? 0
            if errorNumber == -128 {
                throw ExecutionError.userCancelled
            }
            let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            throw ExecutionError.executionFailed(message)
        }
    }
}
