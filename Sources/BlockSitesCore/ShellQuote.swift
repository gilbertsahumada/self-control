import Foundation

/// Safe quoting and escaping helpers for values that flow into a privileged
/// bash script or an AppleScript literal. Every value interpolated into a
/// script must go through one of these helpers — the invariant is that no
/// raw user- or OS-controlled string reaches the shell unescaped.
public enum ShellQuote {

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

    /// Rejects the whole ASCII control-character band (0x00–0x1F and 0x7F).
    /// LF (0x0A) and CR (0x0D) throw `.containsNewline` so callers can
    /// distinguish "line break" from "other control char" — everything
    /// else throws `.containsControlCharacter`. We iterate over Unicode
    /// scalars instead of using `String.contains("\n")` because Swift
    /// collapses `"\r\n"` into a single grapheme cluster, which can cause
    /// substring matches to miss a newline that clearly exists.
    private static func assertPrintable(_ value: String) throws {
        for scalar in value.unicodeScalars {
            let code = scalar.value
            if code == 0x0A || code == 0x0D {
                throw QuotingError.containsNewline
            }
            if code < 0x20 || code == 0x7F {
                throw QuotingError.containsControlCharacter
            }
        }
    }
}
