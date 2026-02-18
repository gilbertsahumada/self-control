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

    /// Runs a shell command with administrator privileges via the native macOS password dialog.
    /// The user sees one password prompt for the entire script.
    static func run(_ shellScript: String) throws {
        // Escape single quotes and backslashes for AppleScript embedding
        let escaped = shellScript
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let source = "do shell script \"\(escaped)\" with administrator privileges"

        guard let script = NSAppleScript(source: source) else {
            throw ExecutionError.scriptCreationFailed
        }

        var errorDict: NSDictionary?
        script.executeAndReturnError(&errorDict)

        if let error = errorDict {
            let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? 0
            // -128 = user cancelled the dialog
            if errorNumber == -128 {
                throw ExecutionError.userCancelled
            }
            let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            throw ExecutionError.executionFailed(message)
        }
    }
}
