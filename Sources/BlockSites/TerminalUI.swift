import Foundation
import BlockSitesCore

enum TerminalUI {
    // MARK: - ANSI Color Codes

    static let reset = "\u{001B}[0m"
    static let bold = "\u{001B}[1m"
    static let dim = "\u{001B}[2m"

    static let red = "\u{001B}[31m"
    static let green = "\u{001B}[32m"
    static let yellow = "\u{001B}[33m"
    static let cyan = "\u{001B}[36m"
    static let white = "\u{001B}[37m"

    static let boldRed = "\u{001B}[1;31m"
    static let boldGreen = "\u{001B}[1;32m"
    static let boldYellow = "\u{001B}[1;33m"
    static let boldCyan = "\u{001B}[1;36m"
    static let boldWhite = "\u{001B}[1;37m"

    // MARK: - Cursor Control

    static func clearScreen() {
        print("\u{001B}[2J\u{001B}[H", terminator: "")
    }

    static func moveCursorUp(_ lines: Int) {
        print("\u{001B}[\(lines)A", terminator: "")
    }

    static func hideCursor() {
        print("\u{001B}[?25l", terminator: "")
    }

    static func showCursor() {
        print("\u{001B}[?25h", terminator: "")
    }

    static func moveToStart() {
        print("\u{001B}[H", terminator: "")
    }

    // MARK: - Box Drawing

    static func printBox(_ lines: [String], width: Int = 37) {
        let inner = width - 2
        print("\(cyan)┌\(String(repeating: "─", count: inner))┐\(reset)")
        for line in lines {
            let stripped = stripAnsi(line)
            let padding = max(0, inner - stripped.count)
            print("\(cyan)│\(reset)\(line)\(String(repeating: " ", count: padding))\(cyan)│\(reset)")
        }
        print("\(cyan)└\(String(repeating: "─", count: inner))┘\(reset)")
    }

    static func printBoxWithDivider(header: [String], body: [String], width: Int = 37) {
        let inner = width - 2
        print("\(cyan)┌\(String(repeating: "─", count: inner))┐\(reset)")
        for line in header {
            let stripped = stripAnsi(line)
            let padding = max(0, inner - stripped.count)
            print("\(cyan)│\(reset)\(line)\(String(repeating: " ", count: padding))\(cyan)│\(reset)")
        }
        print("\(cyan)├\(String(repeating: "─", count: inner))┤\(reset)")
        for line in body {
            let stripped = stripAnsi(line)
            let padding = max(0, inner - stripped.count)
            print("\(cyan)│\(reset)\(line)\(String(repeating: " ", count: padding))\(cyan)│\(reset)")
        }
        print("\(cyan)└\(String(repeating: "─", count: inner))┘\(reset)")
    }

    // MARK: - Progress Bar

    static func progressBar(progress: Double, width: Int = 20) -> String {
        let clamped = max(0, min(1, progress))
        let filled = Int(Double(width) * clamped)
        let empty = width - filled
        let percent = Int(clamped * 100)
        let bar = String(repeating: "█", count: filled) + String(repeating: "░", count: empty)
        return "\(green)\(bar)\(reset)  \(boldWhite)\(percent)%\(reset)"
    }

    // MARK: - Formatted Output

    static func printSuccess(_ message: String) {
        print("\(boldGreen)✓\(reset) \(green)\(message)\(reset)")
    }

    static func printError(_ message: String) {
        print("\(boldRed)✗\(reset) \(red)\(message)\(reset)")
    }

    static func printWarning(_ message: String) {
        print("\(boldYellow)⚠️\(reset) \(yellow)\(message)\(reset)")
    }

    static func printHeader(_ title: String) {
        let width = 35
        let padding = max(0, (width - title.count)) / 2
        let paddedTitle = String(repeating: " ", count: padding) + title
        print("\(boldCyan)\(paddedTitle)\(reset)")
    }

    // MARK: - Input

    static func readInput(prompt: String) -> String {
        print("\(boldWhite)\(prompt)\(reset)", terminator: "")
        fflush(stdout)
        return readLine() ?? ""
    }

    static func confirm(prompt: String) -> Bool {
        let input = readInput(prompt: "\(prompt) [y/N] ")
        return input.lowercased() == "s" || input.lowercased() == "si" || input.lowercased() == "y" || input.lowercased() == "yes"
    }

    // MARK: - Time Formatting (delegates to BlockSitesCore)

    static func formatDuration(_ seconds: TimeInterval) -> String {
        return TimeFormatter.formatDuration(seconds)
    }

    static func formatDurationShort(_ seconds: TimeInterval) -> String {
        return TimeFormatter.formatDurationShort(seconds)
    }

    // MARK: - Subdomain Count (delegates to BlockSitesCore)

    static func subdomainCount(for site: String) -> Int {
        return DomainExpander.subdomainCount(for: site)
    }

    // MARK: - Helpers

    static func stripAnsi(_ string: String) -> String {
        // Remove ANSI escape sequences for accurate length calculation
        var result = string
        while let range = result.range(of: "\u{001B}\\[[0-9;]*m", options: .regularExpression) {
            result.removeSubrange(range)
        }
        return result
    }

    static func centerText(_ text: String, width: Int) -> String {
        let stripped = stripAnsi(text)
        let padding = max(0, (width - stripped.count)) / 2
        return String(repeating: " ", count: padding) + text
    }
}
