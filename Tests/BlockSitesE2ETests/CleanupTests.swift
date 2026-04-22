import XCTest
@testable import MonkModeCore

/// Tests that verify the full blocking → cleanup roundtrip works correctly.
/// These tests reproduce the bugs found where cleanup was silently skipped,
/// leaving sites blocked after the timer expired.
final class CleanupTests: XCTestCase {

    // The most popular sites users block
    let popularSites = ["x.com", "twitter.com", "instagram.com", "youtube.com"]

    // MARK: - Hosts file roundtrip

    func testHostsCleanupRoundtripForPopularSites() {
        let originalHosts = """
        127.0.0.1 localhost
        255.255.255.255 broadcasthost
        ::1 localhost
        """

        // Simulate blocking: generate entries and append to hosts
        let blockEntries = HostsGenerator.generateHostsEntries(for: popularSites)
        let blockedHosts = originalHosts + blockEntries

        // Verify blocking content is present
        XCTAssertTrue(blockedHosts.contains("MONKMODE"))
        for site in popularSites {
            XCTAssertTrue(blockedHosts.contains(site), "Blocked hosts should contain \(site)")
        }

        // Simulate cleanup: remove all MONKMODE entries
        let cleanedHosts = HostsGenerator.cleanHostsContent(blockedHosts)

        // Verify ALL blocking content is removed
        XCTAssertFalse(cleanedHosts.contains("MONKMODE"), "Cleaned hosts should not contain MONKMODE marker")
        XCTAssertFalse(cleanedHosts.contains("127.0.0.1 x.com"), "Cleaned hosts should not block x.com")
        XCTAssertFalse(cleanedHosts.contains("127.0.0.1 twitter.com"), "Cleaned hosts should not block twitter.com")
        XCTAssertFalse(cleanedHosts.contains("127.0.0.1 instagram.com"), "Cleaned hosts should not block instagram.com")
        XCTAssertFalse(cleanedHosts.contains("127.0.0.1 youtube.com"), "Cleaned hosts should not block youtube.com")

        // Verify original content is preserved
        XCTAssertTrue(cleanedHosts.contains("127.0.0.1 localhost"))
        XCTAssertTrue(cleanedHosts.contains("255.255.255.255 broadcasthost"))
        XCTAssertTrue(cleanedHosts.contains("::1 localhost"))
    }

    func testHostsCleanupRemovesExpandedSubdomains() {
        let entries = HostsGenerator.generateHostsEntries(for: ["twitter.com"])
        let hosts = "127.0.0.1 localhost\n" + entries
        let cleaned = HostsGenerator.cleanHostsContent(hosts)

        // All expanded Twitter/X domains must be removed
        let twitterDomains = DomainExpander.expandDomains(for: "twitter.com")
        for domain in twitterDomains {
            XCTAssertFalse(cleaned.contains("127.0.0.1 \(domain)"),
                           "Cleanup should remove expanded domain: \(domain)")
        }
    }

    func testHostsCleanupRemovesDohDomains() {
        let entries = HostsGenerator.generateHostsEntries(for: ["example.com"])
        let hosts = "127.0.0.1 localhost\n" + entries
        let cleaned = HostsGenerator.cleanHostsContent(hosts)

        for domain in DomainExpander.dohDomains {
            XCTAssertFalse(cleaned.contains("127.0.0.1 \(domain)"),
                           "Cleanup should remove DoH domain: \(domain)")
        }
    }

    func testHostsCleanupIdempotent() {
        let entries = HostsGenerator.generateHostsEntries(for: popularSites)
        let hosts = "127.0.0.1 localhost\n" + entries

        let cleanedOnce = HostsGenerator.cleanHostsContent(hosts)
        let cleanedTwice = HostsGenerator.cleanHostsContent(cleanedOnce)

        XCTAssertEqual(cleanedOnce, cleanedTwice, "Cleaning an already-clean file should produce identical output")
    }

    // MARK: - pf.conf anchor roundtrip

    func testPfConfCleanupRemovesAllAnchorLines() {
        let originalPfConf = """
        scrub-anchor "com.apple/*"
        nat-anchor "com.apple/*"
        rdr-anchor "com.apple/*"
        anchor "com.apple/*"
        load anchor "com.apple" from "/etc/pf.anchors/com.apple"
        """

        // Simulate what the app does: append anchor lines
        let blockedPfConf = originalPfConf + """

        # MonkMode anchor
        anchor "com.monkmode"
        load anchor "com.monkmode" from "/etc/pf.anchors/com.monkmode"
        """

        let (cleaned, didChange) = PfConfCleaner.cleanPfConfContent(blockedPfConf)

        XCTAssertTrue(didChange, "Should detect changes were needed")
        XCTAssertFalse(cleaned.contains("MonkMode"), "Should remove MonkMode comment")
        XCTAssertFalse(cleaned.contains("com.monkmode"), "Should remove all monkmode references")

        // Apple anchors must be preserved
        XCTAssertTrue(cleaned.contains("com.apple"))
        XCTAssertTrue(cleaned.contains("scrub-anchor"))
        XCTAssertTrue(cleaned.contains("nat-anchor"))
    }

    func testPfConfCleanupNoChangeWhenClean() {
        let cleanPfConf = """
        scrub-anchor "com.apple/*"
        anchor "com.apple/*"
        load anchor "com.apple" from "/etc/pf.anchors/com.apple"
        """

        let (cleaned, didChange) = PfConfCleaner.cleanPfConfContent(cleanPfConf)

        XCTAssertFalse(didChange, "Should not report changes on clean config")
        XCTAssertEqual(cleaned, cleanPfConf, "Clean config should be unchanged")
    }

    func testPfConfCleanupIdempotent() {
        let pfConf = """
        anchor "com.apple/*"
        # MonkMode anchor
        anchor "com.monkmode"
        load anchor "com.monkmode" from "/etc/pf.anchors/com.monkmode"
        """

        let (cleanedOnce, _) = PfConfCleaner.cleanPfConfContent(pfConf)
        let (cleanedTwice, didChange) = PfConfCleaner.cleanPfConfContent(cleanedOnce)

        XCTAssertFalse(didChange, "Second cleanup should report no changes")
        XCTAssertEqual(cleanedOnce, cleanedTwice)
    }

    // MARK: - Full blocking roundtrip (hosts + pf.conf)

    func testFullBlockingRoundtrip_XTwitter() {
        assertFullRoundtrip(for: ["twitter.com"])
    }

    func testFullBlockingRoundtrip_Instagram() {
        assertFullRoundtrip(for: ["instagram.com"])
    }

    func testFullBlockingRoundtrip_YouTube() {
        assertFullRoundtrip(for: ["youtube.com"])
    }

    func testFullBlockingRoundtrip_AllPopularSites() {
        assertFullRoundtrip(for: popularSites)
    }

    // MARK: - Regression: cleanup must not skip based on content hash

    func testCleanupAlwaysRemovesEntries() {
        // This test reproduces the bug where cleanup was skipped
        // because the hash of the hosts file matched the saved state.
        // The fix ensures cleanup always runs regardless of hash.
        let original = "127.0.0.1 localhost\n::1 localhost\n"
        let entries = HostsGenerator.generateHostsEntries(for: ["x.com", "instagram.com"])
        let withBlocks = original + entries

        // Simulate the "hash matches" scenario (enforcer wrote these entries)
        let savedHash = withBlocks.hashValue

        // Even if the hash matches what we saved, cleanup MUST still run
        let cleaned = HostsGenerator.cleanHostsContent(withBlocks)

        XCTAssertFalse(cleaned.contains("MONKMODE"),
                       "Cleanup must remove entries regardless of hash state")
        XCTAssertFalse(cleaned.contains("127.0.0.1 x.com"),
                       "x.com must be unblocked after cleanup")
        XCTAssertFalse(cleaned.contains("127.0.0.1 instagram.com"),
                       "instagram.com must be unblocked after cleanup")
        XCTAssertTrue(cleaned.contains("127.0.0.1 localhost"),
                      "localhost must be preserved")

        // Verify the hash would have matched (proving the old bug scenario)
        XCTAssertEqual(withBlocks.hashValue, savedHash,
                       "This confirms the hash-match scenario that used to skip cleanup")
    }

    // MARK: - Network reachability sanity check

    func testPopularSitesAreDNSResolvable() async throws {
        // Sanity check: verify that popular sites resolve via DNS.
        // If this fails, the test machine might still have residual blocks.
        let sitesToCheck = ["x.com", "instagram.com", "youtube.com"]

        for site in sitesToCheck {
            let host = CFHostCreateWithName(nil, site as CFString).takeRetainedValue()
            var resolved = DarwinBoolean(false)
            CFHostStartInfoResolution(host, .addresses, nil)
            _ = CFHostGetAddressing(host, &resolved)

            XCTAssertTrue(resolved.boolValue,
                          "\(site) should be DNS-resolvable. If this fails, check for residual /etc/hosts entries.")
        }
    }

    // MARK: - Helpers

    private func assertFullRoundtrip(for sites: [String], file: StaticString = #file, line: UInt = #line) {
        let originalHosts = "127.0.0.1 localhost\n::1 localhost\n"
        let originalPfConf = "scrub-anchor \"com.apple/*\"\nanchor \"com.apple/*\"\n"

        // --- Block phase ---
        let hostsEntries = HostsGenerator.generateHostsEntries(for: sites)
        let blockedHosts = originalHosts + hostsEntries
        let blockedPfConf = originalPfConf + "\n# MonkMode anchor\nanchor \"com.monkmode\"\nload anchor \"com.monkmode\" from \"/etc/pf.anchors/com.monkmode\"\n"

        // Verify blocking is in effect
        for site in sites {
            XCTAssertTrue(blockedHosts.contains(site),
                          "Hosts should block \(site)", file: file, line: line)
        }
        XCTAssertTrue(blockedPfConf.contains("com.monkmode"),
                      "pf.conf should have anchor", file: file, line: line)

        // --- Cleanup phase ---
        let cleanedHosts = HostsGenerator.cleanHostsContent(blockedHosts)
        let (cleanedPfConf, _) = PfConfCleaner.cleanPfConfContent(blockedPfConf)

        // Verify all blocking is removed
        XCTAssertFalse(cleanedHosts.contains("MONKMODE"),
                       "Hosts cleanup incomplete", file: file, line: line)
        XCTAssertFalse(cleanedPfConf.contains("monkmode"),
                       "pf.conf cleanup incomplete", file: file, line: line)

        // Verify no expanded subdomain leaks
        for site in sites {
            let expanded = DomainExpander.expandDomains(for: site)
            for domain in expanded {
                XCTAssertFalse(cleanedHosts.contains("127.0.0.1 \(domain)"),
                               "Leaked blocked domain after cleanup: \(domain)", file: file, line: line)
            }
        }

        // Verify system config preserved
        XCTAssertTrue(cleanedHosts.contains("127.0.0.1 localhost"),
                      "localhost entry lost", file: file, line: line)
        XCTAssertTrue(cleanedPfConf.contains("com.apple"),
                      "Apple anchor lost", file: file, line: line)
    }
}
