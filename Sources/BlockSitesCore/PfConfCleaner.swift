import Foundation

public enum PfConfCleaner {
    private static let anchorComment = "# MonkMode anchor"
    private static let anchorDeclaration = "anchor \"com.monkmode\""
    private static let anchorLoad = "load anchor \"com.monkmode\""

    /// Generates the pf.conf anchor lines that should be appended during blocking.
    public static func generateAnchorLines() -> String {
        return """

        \(anchorComment)
        \(anchorDeclaration)
        \(anchorLoad) from "/etc/pf.anchors/com.monkmode"

        """
    }

    /// Removes all MonkMode anchor references from pf.conf content.
    /// Returns the cleaned content, or nil if no changes were needed.
    public static func cleanPfConfContent(_ content: String) -> (cleaned: String, didChange: Bool) {
        let lines = content.components(separatedBy: .newlines)
        let cleanedLines = lines.filter { line in
            !line.contains(anchorComment) &&
            !line.contains(anchorDeclaration) &&
            !line.contains(anchorLoad)
        }

        let didChange = cleanedLines.count != lines.count
        return (cleanedLines.joined(separator: "\n"), didChange)
    }
}
