import XCTest
@testable import MonkModeCore

final class ShellQuoteTests: XCTestCase {

    // MARK: - posixSingleQuote

    func testPosixQuote_simpleValue() throws {
        XCTAssertEqual(try ShellQuote.posixSingleQuote("hello"), "'hello'")
    }

    func testPosixQuote_emptyString() throws {
        XCTAssertEqual(try ShellQuote.posixSingleQuote(""), "''")
    }

    func testPosixQuote_pathWithSpaces() throws {
        XCTAssertEqual(
            try ShellQuote.posixSingleQuote("/Applications/Monk Mode.app"),
            "'/Applications/Monk Mode.app'"
        )
    }

    func testPosixQuote_valueWithSingleQuote() throws {
        XCTAssertEqual(
            try ShellQuote.posixSingleQuote("it's fine"),
            "'it'\\''s fine'"
        )
    }

    func testPosixQuote_valueWithManyShellMetacharacters() throws {
        // Inputs with no single quote pass through unchanged inside '...'
        // which is exactly the point: the shell does not interpret anything
        // between single quotes.
        let input = "$(rm -rf /); echo \"pwned\" | cat"
        XCTAssertEqual(try ShellQuote.posixSingleQuote(input), "'\(input)'")
    }

    func testPosixQuote_rejectsNewline() {
        XCTAssertThrowsError(try ShellQuote.posixSingleQuote("a\nb")) { err in
            XCTAssertEqual(err as? ShellQuote.QuotingError, .containsNewline)
        }
    }

    func testPosixQuote_rejectsCarriageReturn() {
        XCTAssertThrowsError(try ShellQuote.posixSingleQuote("a\rb")) { err in
            XCTAssertEqual(err as? ShellQuote.QuotingError, .containsNewline)
        }
    }

    func testPosixQuote_rejectsNullByte() {
        XCTAssertThrowsError(try ShellQuote.posixSingleQuote("a\u{0000}b")) { err in
            XCTAssertEqual(err as? ShellQuote.QuotingError, .containsControlCharacter)
        }
    }

    func testPosixQuote_rejectsBackspace() {
        XCTAssertThrowsError(try ShellQuote.posixSingleQuote("a\u{0008}b"))
    }

    // MARK: - appleScriptLiteral

    func testAppleScriptLiteral_simple() throws {
        XCTAssertEqual(try ShellQuote.appleScriptLiteral("hello"), "hello")
    }

    func testAppleScriptLiteral_escapesBackslash() throws {
        XCTAssertEqual(try ShellQuote.appleScriptLiteral("a\\b"), "a\\\\b")
    }

    func testAppleScriptLiteral_escapesDoubleQuote() throws {
        XCTAssertEqual(try ShellQuote.appleScriptLiteral("he said \"hi\""), "he said \\\"hi\\\"")
    }

    func testAppleScriptLiteral_escapesBothOrderIndependent() throws {
        // Backslash must be escaped first so we don't double-escape the
        // backslash introduced by escaping a quote.
        XCTAssertEqual(
            try ShellQuote.appleScriptLiteral("a\\\"b"),
            "a\\\\\\\"b"
        )
    }

    func testAppleScriptLiteral_rejectsNewline() {
        XCTAssertThrowsError(try ShellQuote.appleScriptLiteral("a\nb"))
    }

    func testAppleScriptLiteral_rejectsControlChar() {
        XCTAssertThrowsError(try ShellQuote.appleScriptLiteral("a\u{0001}b"))
    }

    // MARK: - sedBRE

    func testSedBRE_escapesSlash() throws {
        XCTAssertEqual(try ShellQuote.sedBRE("a/b"), "a\\/b")
    }

    func testSedBRE_escapesDotAndStar() throws {
        XCTAssertEqual(try ShellQuote.sedBRE(".*"), "\\.\\*")
    }

    func testSedBRE_escapesAnchorsAndAmpersand() throws {
        XCTAssertEqual(try ShellQuote.sedBRE("^$&"), "\\^\\$\\&")
    }

    func testSedBRE_escapesBrackets() throws {
        XCTAssertEqual(try ShellQuote.sedBRE("[abc]"), "\\[abc\\]")
    }

    func testSedBRE_rejectsNewline() {
        XCTAssertThrowsError(try ShellQuote.sedBRE("a\nb"))
    }
}
