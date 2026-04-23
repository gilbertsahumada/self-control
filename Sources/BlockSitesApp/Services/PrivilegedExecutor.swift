import Foundation
import MonkModeCore

enum PrivilegedExecutor {
    enum ExecutionError: LocalizedError {
        case scriptCreationFailed
        case executionFailed(String)
        case userCancelled
        case unsafeScriptPath

        var errorDescription: String? {
            switch self {
            case .scriptCreationFailed:
                return "Failed to create AppleScript"
            case .executionFailed(let message):
                return "Execution failed: \(message)"
            case .userCancelled:
                return "User cancelled the operation"
            case .unsafeScriptPath:
                return "Script path contains characters that are unsafe to pass to the shell"
            }
        }
    }

    /// Writes `shellScript` to a temp file and runs it with admin privileges
    /// via `NSAppleScript`. Both quoting layers — the POSIX shell and the
    /// AppleScript string literal — are escaped via `ShellQuote` so a
    /// pathological temp directory path cannot break out and execute
    /// arbitrary AppleScript or shell code as root.
    static func run(_ shellScript: String) throws {
        let tempDir = FileManager.default.temporaryDirectory
        let scriptPath = tempDir.appendingPathComponent("monkmode_script_\(UUID().uuidString).sh")
        try shellScript.write(to: scriptPath, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: scriptPath)
        }

        // Layer 1: escape the path for POSIX single-quoting inside `bash '...'`.
        let shellQuotedPath: String
        do {
            shellQuotedPath = try ShellQuote.posixSingleQuote(scriptPath.path)
        } catch {
            throw ExecutionError.unsafeScriptPath
        }

        // Layer 2: the whole shell command becomes an AppleScript string
        // literal. We must escape `\` and `"` for the AppleScript parser.
        let shellCommand = "bash \(shellQuotedPath)"
        let appleScriptLiteral: String
        do {
            appleScriptLiteral = try ShellQuote.appleScriptLiteral(shellCommand)
        } catch {
            throw ExecutionError.unsafeScriptPath
        }

        let source = "do shell script \"\(appleScriptLiteral)\" with administrator privileges"

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
