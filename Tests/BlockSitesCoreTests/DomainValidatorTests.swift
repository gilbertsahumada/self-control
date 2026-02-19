import XCTest
@testable import SelfControlCore

final class DomainValidatorTests: XCTestCase {

    func testValidSimpleDomain() {
        XCTAssertTrue(DomainValidator.isValid("example.com"))
        XCTAssertTrue(DomainValidator.isValid("test.org"))
        XCTAssertTrue(DomainValidator.isValid("domain.net"))
    }

    func testValidSubdomain() {
        XCTAssertTrue(DomainValidator.isValid("sub.example.com"))
        XCTAssertTrue(DomainValidator.isValid("www.example.com"))
        XCTAssertTrue(DomainValidator.isValid("a.b.c.example.com"))
    }

    func testValidWithNumbers() {
        XCTAssertTrue(DomainValidator.isValid("example123.com"))
        XCTAssertTrue(DomainValidator.isValid("123example.com"))
        XCTAssertTrue(DomainValidator.isValid("site2.example.com"))
    }

    func testValidWithHyphen() {
        XCTAssertTrue(DomainValidator.isValid("my-site.com"))
        XCTAssertTrue(DomainValidator.isValid("a-b-c.example.com"))
    }

    func testInvalidEmptyString() {
        XCTAssertFalse(DomainValidator.isValid(""))
        XCTAssertFalse(DomainValidator.isValid("   "))
    }

    func testInvalidWithSpaces() {
        XCTAssertFalse(DomainValidator.isValid("example com"))
        XCTAssertFalse(DomainValidator.isValid("exam ple.com"))
    }

    func testInvalidWithSpecialCharacters() {
        XCTAssertFalse(DomainValidator.isValid("example@com"))
        XCTAssertFalse(DomainValidator.isValid("example!com"))
        XCTAssertFalse(DomainValidator.isValid("example#com"))
    }

    func testInvalidStartsWithHyphen() {
        XCTAssertFalse(DomainValidator.isValid("-example.com"))
        XCTAssertFalse(DomainValidator.isValid("-example-.com"))
    }

    func testInvalidEndsWithHyphen() {
        XCTAssertFalse(DomainValidator.isValid("example-.com"))
    }

    func testInvalidIPAddress() {
        XCTAssertFalse(DomainValidator.isValid("192.168.1.1"))
        XCTAssertFalse(DomainValidator.isValid("127.0.0.1"))
    }

    func testInvalidWildcard() {
        XCTAssertFalse(DomainValidator.isValid("*.example.com"))
        XCTAssertFalse(DomainValidator.isValid("*"))
    }

    func testInvalidURL() {
        XCTAssertFalse(DomainValidator.isValid("https://example.com"))
        XCTAssertFalse(DomainValidator.isValid("http://example.com"))
        XCTAssertFalse(DomainValidator.isValid("www.example.com/path"))
    }

    func testValidWithCommonTLDs() {
        XCTAssertTrue(DomainValidator.isValid("example.com"))
        XCTAssertTrue(DomainValidator.isValid("example.org"))
        XCTAssertTrue(DomainValidator.isValid("example.net"))
        XCTAssertTrue(DomainValidator.isValid("example.io"))
        XCTAssertTrue(DomainValidator.isValid("example.co"))
    }

    func testSanitizeForHosts() {
        XCTAssertEqual(DomainValidator.sanitizeForHosts("  Example.COM  "), "example.com")
        XCTAssertEqual(DomainValidator.sanitizeForHosts("test site.com"), "testsite.com")
    }

    func testValidateAndCleanReturnsValidAndInvalid() {
        let (valid, invalid) = DomainValidator.validateAndClean([
            "example.com",
            "  test.org  ",
            "not a domain",
            "",
            "*.wildcard.com"
        ])

        XCTAssertTrue(valid.contains("example.com"))
        XCTAssertTrue(valid.contains("test.org"))
        XCTAssertEqual(valid.count, 2)
        XCTAssertEqual(invalid.count, 3)
    }

    func testValidateAndCleanDeduplicates() {
        let (valid, invalid) = DomainValidator.validateAndClean([
            "example.com",
            "EXAMPLE.COM",
            "Example.com",
            "example.com"
        ])

        XCTAssertEqual(valid.count, 1)
        XCTAssertEqual(valid.first, "example.com")
    }

    func testLongValidDomain() {
        XCTAssertTrue(DomainValidator.isValid("this-is-a-very-long-domain-name-that-is-still-valid.com"))
    }

    func testTooLongDomain() {
        let tooLongDomain = String(repeating: "a", count: 254)
        XCTAssertFalse(DomainValidator.isValid(tooLongDomain))
    }
}
