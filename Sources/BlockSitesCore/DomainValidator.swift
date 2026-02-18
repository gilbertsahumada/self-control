import Foundation

public enum DomainValidator {
    private static let domainRegex = #"^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$"#

    public static func isValid(_ domain: String) -> Bool {
        let trimmed = domain.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.count <= 253 else { return false }
        return trimmed.range(of: domainRegex, options: .regularExpression) != nil
    }

    public static func validateAndClean(_ domains: [String]) -> (valid: [String], invalid: [String]) {
        let cleaned = domains.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        let unique = Array(Set(cleaned))
        let valid = unique.filter { isValid($0) }
        let invalid = unique.filter { !isValid($0) }
        return (valid, invalid)
    }

    public static func sanitizeForHosts(_ domain: String) -> String {
        return domain
            .lowercased()
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "")
    }
}
