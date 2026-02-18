import XCTest
@testable import BlockSitesCore

final class HostsGeneratorTests: XCTestCase {

    // MARK: - generateHostsEntries

    func testGenerateHostsEntriesContains127() {
        let entries = HostsGenerator.generateHostsEntries(for: ["example.com"])
        let lines = entries.components(separatedBy: .newlines).filter { !$0.isEmpty }
        let entryLines = lines.filter { $0.hasPrefix("127.0.0.1") }
        XCTAssertFalse(entryLines.isEmpty)
        for line in entryLines {
            XCTAssertTrue(line.hasPrefix("127.0.0.1 "), "Entry should start with 127.0.0.1: \(line)")
        }
    }

    func testGenerateHostsEntriesContainsMarker() {
        let entries = HostsGenerator.generateHostsEntries(for: ["example.com"], marker: "# TEST")
        let lines = entries.components(separatedBy: .newlines).filter { !$0.isEmpty }
        let entryLines = lines.filter { $0.hasPrefix("127.0.0.1") }
        for line in entryLines {
            XCTAssertTrue(line.contains("# TEST"), "Entry should contain marker: \(line)")
        }
    }

    func testGenerateHostsEntriesHasStartEndMarkers() {
        let entries = HostsGenerator.generateHostsEntries(for: ["example.com"])
        XCTAssertTrue(entries.contains("# BLOCKSITES START"))
        XCTAssertTrue(entries.contains("# BLOCKSITES END"))
    }

    func testGenerateHostsEntriesMultipleSites() {
        let entries = HostsGenerator.generateHostsEntries(for: ["example.com", "test.org"])
        XCTAssertTrue(entries.contains("example.com"))
        XCTAssertTrue(entries.contains("test.org"))
        XCTAssertTrue(entries.contains("www.example.com"))
        XCTAssertTrue(entries.contains("www.test.org"))
    }

    func testGenerateHostsEntriesIncludesAllExpandedDomains() {
        let entries = HostsGenerator.generateHostsEntries(for: ["example.com"])
        let expanded = DomainExpander.expandDomains(for: "example.com")
        for domain in expanded {
            XCTAssertTrue(entries.contains("127.0.0.1 \(domain)"),
                          "Missing hosts entry for \(domain)")
        }
    }

    func testGenerateHostsEntriesIncludesDohDomains() {
        let entries = HostsGenerator.generateHostsEntries(for: ["example.com"])
        for domain in DomainExpander.dohDomains {
            XCTAssertTrue(entries.contains("127.0.0.1 \(domain)"),
                          "Missing DoH domain entry for \(domain)")
        }
    }

    // MARK: - cleanHostsContent

    func testCleanHostsContentRemovesMarkedLines() {
        let content = """
        127.0.0.1 localhost
        # BLOCKSITES START
        127.0.0.1 example.com # BLOCKSITES
        127.0.0.1 www.example.com # BLOCKSITES
        # BLOCKSITES END
        ::1 localhost
        """
        let cleaned = HostsGenerator.cleanHostsContent(content)
        XCTAssertFalse(cleaned.contains("example.com"))
        XCTAssertFalse(cleaned.contains("BLOCKSITES"))
    }

    func testCleanHostsContentPreservesOtherLines() {
        let content = """
        127.0.0.1 localhost
        # BLOCKSITES START
        127.0.0.1 example.com # BLOCKSITES
        # BLOCKSITES END
        ::1 localhost
        255.255.255.255 broadcasthost
        """
        let cleaned = HostsGenerator.cleanHostsContent(content)
        XCTAssertTrue(cleaned.contains("127.0.0.1 localhost"))
        XCTAssertTrue(cleaned.contains("::1 localhost"))
        XCTAssertTrue(cleaned.contains("255.255.255.255 broadcasthost"))
    }

    func testCleanHostsContentWithCustomMarker() {
        let content = """
        127.0.0.1 localhost
        127.0.0.1 example.com # CUSTOM
        ::1 localhost
        """
        let cleaned = HostsGenerator.cleanHostsContent(content, marker: "# CUSTOM")
        XCTAssertFalse(cleaned.contains("example.com"))
        XCTAssertTrue(cleaned.contains("127.0.0.1 localhost"))
    }

    func testCleanHostsContentNoMarkedLines() {
        let content = """
        127.0.0.1 localhost
        ::1 localhost
        """
        let cleaned = HostsGenerator.cleanHostsContent(content)
        XCTAssertTrue(cleaned.contains("127.0.0.1 localhost"))
        XCTAssertTrue(cleaned.contains("::1 localhost"))
    }
}
