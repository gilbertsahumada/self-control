import Foundation

/// Safe quoting and escaping helpers for values that flow into a privileged
/// bash script or an AppleScript literal. Every value interpolated into a
/// script must go through one of these helpers — the invariant is that no
/// raw user- or OS-controlled string reaches the shell unescaped.
public enum ShellQuote {

    /// Characters that must not appear in any value we are about to quote.
    /// These break the surrounding quoting layer regardless of escape tricks.
    /// NUL is rejected because Unix tools truncate on it; newline and carriage
    /// return are rejected because they would start a new command in bash
    /// (even inside single quotes if the outer layer were ever split).
    private static let forbiddenControlCharacters: Set<Character> = {
        var set: Set<Character> = ["\u{0000}"]
        for scalar in 0x01...0x08 { set.insert(Character(UnicodeScalar(scalar)!)) }
        for scalar in 0x0B...0x0C { set.insert(Character(UnicodeScalar(scalar)!)) }
        for scalar in 0x0E...0x1F { set.insert(Character(UnicodeScalar(scalar)!)) }
        set.insert("\u{007F}")
        return set
    }()

    public enum QuotingError: Error, Equatable {
        case containsControlCharacter
        case containsNewline
    }

    /// Returns a single-quoted POSIX-shell-safe form of `value`.
    /// Embedded single quotes are escaped via the standard \`'\\''\` trick.
    /// Throws if the input contains control characters or line breaks that
    /// would be unsafe even inside single quotes.
    public static func posixSingleQuote(_ value: String) throws -> String {
        try assertPrintable(value)
        let escaped = value.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }

    /// Returns an AppleScript string-literal-safe form of `value`.
    /// Escapes backslash and double-quote. Throws on control chars / newlines.
    /// Callers wrap the result in \`\"...\"\`.
    public static func appleScriptLiteral(_ value: String) throws -> String {
        try assertPrintable(value)
        return value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// Returns a `sed` BRE pattern with the common metacharacters escaped.
    /// Reject control characters too. Only intended for building simple
    /// \`/pattern/d\` deletions — not a full sed-regex-sanitizer.
    public static func sedBRE(_ pattern: String) throws -> String {
        try assertPrintable(pattern)
        var escaped = ""
        for char in pattern {
            switch char {
            case "\\", "/", "[", "]", ".", "*", "^", "$", "&":
                escaped.append("\\")
                escaped.append(char)
            default:
                escaped.append(char)
            }
        }
        return escaped
    }

    private static func assertPrintable(_ value: String) throws {
        if value.contains("\n") || value.contains("\r") {
            throw QuotingError.containsNewline
        }
        for char in value where forbiddenControlCharacters.contains(char) {
            throw QuotingError.containsControlCharacter
        }
    }
}
