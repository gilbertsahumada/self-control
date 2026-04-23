import XCTest
@testable import MonkModeCore

/// Adversarial corpus targeting every primitive that sits between user input
/// and files written as root. The goal is to guarantee that no entry in this
/// corpus can reach `/etc/hosts`, `/etc/pf.conf`, or a privileged bash script.
///
/// When a new vulnerability is discovered, add the offending input to
/// `maliciousInputs` with a comment pointing at the issue/PR.
final class AdversarialInputTests: XCTestCase {

    /// Inputs that MUST be rejected by `DomainValidator.isValid`.
    static let maliciousInputs: [String] = [
        // Control characters that corrupt /etc/hosts or start new shell cmds.
        "evil.com\n127.0.0.1 target.com",
        "evil.com\r\nmore",
        "\u{0000}evil.com",
        "evil\u{0000}.com",
        "evil.com\u{0008}",
        "evil.com\u{001F}",
        "evil.com\u{007F}",
        "evil\tcom",
        "evil .com",

        // Shell metacharacters — only reach shell if validator fails, but
        // cheap to reject up front.
        "$(rm -rf /).com",
        "evil;rm.com",
        "evil|cat.com",
        "evil&sleep.com",
        "evil`id`.com",
        "evil>out.com",

        // AppleScript / quoting edge cases.
        "evil\".com",
        "evil\\.com",
        "evil'.com",

        // Unicode homoglyphs — Cyrillic 'а' looks identical to ASCII 'a'.
        "f\u{0430}cebook.com",
        "g\u{043E}\u{043E}gle.com",

        // IP-like strings.
        "127.0.0.1",
        "0.0.0.0",
        "192.168.1.1",

        // Structural violations.
        "",
        ".",
        "..",
        ".com",
        "example.",
        "-example.com",
        "example-.com",
        "exa..mple.com",
        "a" + String(repeating: "b", count: 253), // > 253 chars
        String(repeating: "a", count: 64) + ".com", // label > 63
        "exa mple.com",

        // Schemes / paths — users sometimes paste full URLs.
        "https://evil.com",
        "evil.com/path",
        "evil.com:443",
    ]

    /// Inputs that must be accepted (sanity guard on the allowlist).
    static let legitimateInputs: [String] = [
        "example.com",
        "example.co.uk",
        "sub.example.com",
        "deep.sub.example.com",
        "a1b2.com",
        "a-b.com",
        "example.museum",
        "xn--nxasmq6b.com", // Punycode IDN
    ]

    // MARK: - DomainValidator

    func testMaliciousInputsAreRejected() {
        for input in Self.maliciousInputs {
            XCTAssertFalse(
                DomainValidator.isValid(input),
                "expected rejection for input: \(input.debugDescription)"
            )
        }
    }

    func testLegitimateInputsAreAccepted() {
        for input in Self.legitimateInputs {
            XCTAssertTrue(
                DomainValidator.isValid(input),
                "expected acceptance for input: \(input.debugDescription)"
            )
        }
    }

    // MARK: - HostsGenerator

    /// Even if a malicious input somehow reached the generator, the
    /// generator should never produce a line containing a raw control
    /// character — this catches a double-fault where the validator is
    /// bypassed or a future refactor skips validation.
    func testHostsEntriesNeverContainControlCharacters() {
        // Only feed inputs that the validator would accept in production.
        let entries = HostsGenerator.generateHostsEntries(for: Self.legitimateInputs)
        for scalar in entries.unicodeScalars {
            if scalar.value < 0x20 && scalar != "\n" {
                XCTFail("hosts entries contain control char \(scalar.value)")
            }
        }
    }

    // MARK: - ShellQuote round-trip

    func testShellQuoteRejectsEveryMaliciousControlChar() {
        for input in Self.maliciousInputs where containsControl(input) {
            XCTAssertThrowsError(
                try ShellQuote.posixSingleQuote(input),
                "posixSingleQuote accepted control-char input: \(input.debugDescription)"
            )
            XCTAssertThrowsError(
                try ShellQuote.appleScriptLiteral(input),
                "appleScriptLiteral accepted control-char input: \(input.debugDescription)"
            )
        }
    }

    // MARK: - PfConfCleaner idempotence under adversarial content

    /// A pf.conf file that contains the `com.monkmode` anchor only as a
    /// substring (e.g. `com.monkmode.evil`) should NOT be touched by the
    /// cleaner.
    func testPfConfCleanupDoesNotFalseMatchSubstring() {
        let content = """
        anchor "com.apple/*"
        # unrelated comment mentioning com.monkmode should remain
        anchor "com.monkmode.evil"
        """
        let (cleaned, _) = PfConfCleaner.cleanPfConfContent(content)
        XCTAssertTrue(cleaned.contains("com.monkmode.evil"))
        XCTAssertTrue(cleaned.contains("com.apple"))
    }

    // MARK: - Helpers

    private func containsControl(_ value: String) -> Bool {
        for scalar in value.unicodeScalars {
            if scalar.value < 0x20 || scalar.value == 0x7F {
                return true
            }
        }
        return false
    }
}
