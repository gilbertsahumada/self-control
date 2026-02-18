import XCTest
@testable import BlockSitesCore

final class ScriptGenerationTests: XCTestCase {

    func testHostsEntriesContainValidDomains() {
        let entries = HostsGenerator.generateHostsEntries(for: ["example.com"])
        XCTAssertTrue(entries.contains("127.0.0.1 example.com"))
    }

    func testHostsEntriesContainSubdomains() {
        let entries = HostsGenerator.generateHostsEntries(for: ["example.com"])
        XCTAssertTrue(entries.contains("127.0.0.1 www.example.com"))
        XCTAssertTrue(entries.contains("127.0.0.1 mobile.example.com"))
        XCTAssertTrue(entries.contains("127.0.0.1 api.example.com"))
    }

    func testHostsEntriesContainDohDomains() {
        let entries = HostsGenerator.generateHostsEntries(for: ["example.com"])
        XCTAssertTrue(entries.contains("127.0.0.1 dns.google"))
        XCTAssertTrue(entries.contains("127.0.0.1 cloudflare-dns.com"))
    }

    func testHostsEntriesHaveStartAndEndMarkers() {
        let entries = HostsGenerator.generateHostsEntries(for: ["example.com"])
        XCTAssertTrue(entries.contains("# BLOCKSITES START"))
        XCTAssertTrue(entries.contains("# BLOCKSITES END"))
    }

    func testCleanHostsContentRemovesAllMarkedLines() {
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
        XCTAssertFalse(cleaned.contains("www.example.com"))
        XCTAssertTrue(cleaned.contains("localhost"))
    }

    func testCleanHostsContentPreservesOtherContent() {
        let content = """
        127.0.0.1 localhost
        ::1 localhost
        255.255.255.255 broadcasthost
        # BLOCKSITES START
        127.0.0.1 example.com # BLOCKSITES
        # BLOCKSITES END
        """
        let cleaned = HostsGenerator.cleanHostsContent(content)
        XCTAssertTrue(cleaned.contains("255.255.255.255 broadcasthost"))
        XCTAssertTrue(cleaned.contains("127.0.0.1 localhost"))
    }

    func testCleanHostsContentWithCustomMarker() {
        let content = """
        127.0.0.1 localhost
        127.0.0.1 example.com # CUSTOM_MARKER
        ::1 localhost
        """
        let cleaned = HostsGenerator.cleanHostsContent(content, marker: "# CUSTOM_MARKER")
        XCTAssertFalse(cleaned.contains("example.com"))
        XCTAssertTrue(cleaned.contains("localhost"))
    }

    func testNoDuplicateEntriesInHosts() {
        let entries = HostsGenerator.generateHostsEntries(for: ["example.com"])
        let lines = entries.components(separatedBy: .newlines)
        let domainLines = lines.filter { $0.contains("example.com") }
        let uniqueLines = Set(domainLines.filter { !$0.isEmpty })
        XCTAssertEqual(domainLines.filter { !$0.isEmpty }.count, uniqueLines.count)
    }
}
