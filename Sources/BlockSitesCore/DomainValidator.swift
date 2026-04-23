import Foundation

/// Validates domain strings entered by the user before they flow into files
/// written as root (/etc/hosts) or rules passed to pf. The validator is
/// intentionally strict:
///
/// - Only ASCII letters, digits, `.`, and `-`.
/// - Each label 1-63 chars, no leading/trailing hyphen.
/// - Total length 1-253 chars.
/// - No control characters anywhere in the input.
/// - TLD must be ≥ 2 alphabetic characters.
/// - IP-address-like strings are rejected.
///
/// Callers that need to accept internationalized domains should Punycode
/// them (`xn--...`) before passing them here.
public enum DomainValidator {
    private static let domainRegex = #"^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)*\.[a-z]{2,}$"#

    /// Rejects any control character (U+0000–U+001F, U+007F). This catches
    /// NUL, newline, carriage return, tab, and anything that would
    /// corrupt `/etc/hosts` or be unsafe to pass into a privileged script.
    private static func containsControlCharacter(_ value: String) -> Bool {
        for scalar in value.unicodeScalars {
            if scalar.value < 0x20 || scalar.value == 0x7F {
                return true
            }
        }
        return false
    }

    /// Rejects anything that is not pure ASCII. Unicode homoglyphs
    /// (`fаcebook.com` with a Cyrillic `а`) look identical to users but
    /// DNS treats them as different names, so the block would silently
    /// fail. Callers must Punycode first.
    private static func isPureASCII(_ value: String) -> Bool {
        return value.unicodeScalars.allSatisfy { $0.isASCII }
    }

    public static func isValid(_ domain: String) -> Bool {
        if containsControlCharacter(domain) { return false }
        let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 253 else { return false }
        guard isPureASCII(trimmed) else { return false }
        let normalized = trimmed.lowercased()
        if normalized.allSatisfy({ $0.isNumber || $0 == "." }) { return false }
        return normalized.range(of: domainRegex, options: .regularExpression) != nil
    }

    public static func validateAndClean(_ domains: [String]) -> (valid: [String], invalid: [String]) {
        var valid: [String] = []
        var invalid: [String] = []
        var seen: Set<String> = []
        for raw in domains {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if trimmed.isEmpty { continue }
            if !isValid(trimmed) {
                if !seen.contains(trimmed) {
                    invalid.append(trimmed)
                    seen.insert(trimmed)
                }
                continue
            }
            if seen.contains(trimmed) { continue }
            seen.insert(trimmed)
            valid.append(trimmed)
        }
        return (valid, invalid)
    }

    public static func sanitizeForHosts(_ domain: String) -> String {
        let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.filter { char in
            guard let scalar = char.unicodeScalars.first else { return false }
            let v = scalar.value
            return (v >= 0x30 && v <= 0x39)   // 0-9
                || (v >= 0x61 && v <= 0x7A)   // a-z
                || v == 0x2D                  // -
                || v == 0x2E                  // .
        }
    }
}
