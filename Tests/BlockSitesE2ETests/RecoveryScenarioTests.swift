import XCTest
@testable import MonkModeCore

/// Simulates the "stale block" recovery path: a user's system has residual
/// MONKMODE entries in /etc/hosts and a leftover com.monkmode anchor in
/// /etc/pf.conf, but config.json is gone (e.g. the enforcer daemon failed to
/// clean up, or the user wiped Application Support but not /etc).
///
/// These tests run against in-memory strings only — they never touch the
/// real /etc/hosts or /etc/pf.conf.
final class RecoveryScenarioTests: XCTestCase {

    // MARK: - Fixtures

    private let residualHosts = """
    ##
    # Host Database
    ##
    127.0.0.1 localhost
    ::1 localhost
    255.255.255.255 broadcasthost
    # MONKMODE START
    127.0.0.1 x.com # MONKMODE
    127.0.0.1 www.x.com # MONKMODE
    127.0.0.1 twitter.com # MONKMODE
    127.0.0.1 www.twitter.com # MONKMODE
    127.0.0.1 instagram.com # MONKMODE
    127.0.0.1 www.instagram.com # MONKMODE
    127.0.0.1 dns.google # MONKMODE
    127.0.0.1 cloudflare-dns.com # MONKMODE
    # MONKMODE END
    """

    private let residualPfConf = """
    scrub-anchor "com.apple/*"
    nat-anchor "com.apple/*"
    rdr-anchor "com.apple/*"
    dummynet-anchor "com.apple/*"
    anchor "com.apple/*"
    load anchor "com.apple" from "/etc/pf.anchors/com.apple"

    # MonkMode anchor
    anchor "com.monkmode"
    load anchor "com.monkmode" from "/etc/pf.anchors/com.monkmode"
    """

    // MARK: - Hosts recovery

    func testRecoveryStripsAllMarkerLinesFromHosts() {
        let cleaned = HostsGenerator.cleanHostsContent(residualHosts)

        XCTAssertFalse(cleaned.contains("MONKMODE"),
                       "Recovery must remove every MONKMODE marker line")
        XCTAssertFalse(cleaned.contains("127.0.0.1 x.com"))
        XCTAssertFalse(cleaned.contains("127.0.0.1 twitter.com"))
        XCTAssertFalse(cleaned.contains("127.0.0.1 instagram.com"))
        XCTAssertFalse(cleaned.contains("dns.google"))
        XCTAssertFalse(cleaned.contains("cloudflare-dns.com"))
    }

    func testRecoveryPreservesSystemHostsEntries() {
        let cleaned = HostsGenerator.cleanHostsContent(residualHosts)

        XCTAssertTrue(cleaned.contains("127.0.0.1 localhost"))
        XCTAssertTrue(cleaned.contains("::1 localhost"))
        XCTAssertTrue(cleaned.contains("255.255.255.255 broadcasthost"))
        XCTAssertTrue(cleaned.contains("# Host Database"))
    }

    // MARK: - pf.conf recovery

    func testRecoveryStripsAnchorFromPfConf() {
        let (cleaned, didChange) = PfConfCleaner.cleanPfConfContent(residualPfConf)

        XCTAssertTrue(didChange, "Recovery path should detect changes are needed")
        XCTAssertFalse(cleaned.contains("com.monkmode"),
                       "Recovery must remove every com.monkmode reference")
        XCTAssertFalse(cleaned.contains("MonkMode"),
                       "Recovery must remove the MonkMode anchor comment")
    }

    func testRecoveryPreservesApplePfAnchors() {
        let (cleaned, _) = PfConfCleaner.cleanPfConfContent(residualPfConf)

        XCTAssertTrue(cleaned.contains("scrub-anchor \"com.apple/*\""))
        XCTAssertTrue(cleaned.contains("nat-anchor \"com.apple/*\""))
        XCTAssertTrue(cleaned.contains("rdr-anchor \"com.apple/*\""))
        XCTAssertTrue(cleaned.contains("dummynet-anchor \"com.apple/*\""))
        XCTAssertTrue(cleaned.contains("anchor \"com.apple/*\""))
        XCTAssertTrue(cleaned.contains("load anchor \"com.apple\""))
    }

    // MARK: - Combined flow: what runRecoveryCleanup expects in-memory

    func testFullRecoveryProducesFullyCleanOutputs() {
        let cleanedHosts = HostsGenerator.cleanHostsContent(residualHosts)
        let (cleanedPfConf, _) = PfConfCleaner.cleanPfConfContent(residualPfConf)

        // Hosts: no markers left, and no residual blocked IPs on 127.0.0.1
        // other than localhost.
        XCTAssertFalse(cleanedHosts.contains(MonkModeConstants.marker))
        let hostsLoopbackLines = cleanedHosts
            .components(separatedBy: .newlines)
            .filter { $0.hasPrefix("127.0.0.1") }
        for line in hostsLoopbackLines {
            XCTAssertTrue(line.contains("localhost"),
                          "Unexpected residual 127.0.0.1 entry after recovery: \(line)")
        }

        // pf.conf: no monkmode strings at all.
        XCTAssertFalse(cleanedPfConf.contains(MonkModeConstants.pfAnchorName))
        XCTAssertFalse(cleanedPfConf.lowercased().contains("monkmode"))
    }

    func testRecoveryIsIdempotent() {
        // Running the recovery flow twice must be a no-op the second time,
        // which matches the shape of the shell recovery script (`set +e`).
        let cleanedHostsOnce = HostsGenerator.cleanHostsContent(residualHosts)
        let cleanedHostsTwice = HostsGenerator.cleanHostsContent(cleanedHostsOnce)
        XCTAssertEqual(cleanedHostsOnce, cleanedHostsTwice)

        let (cleanedPfOnce, _) = PfConfCleaner.cleanPfConfContent(residualPfConf)
        let (cleanedPfTwice, didChangeSecond) = PfConfCleaner.cleanPfConfContent(cleanedPfOnce)
        XCTAssertFalse(didChangeSecond,
                       "Second cleanup pass must not report changes on an already-clean pf.conf")
        XCTAssertEqual(cleanedPfOnce, cleanedPfTwice)
    }

    // MARK: - Stale-detection heuristic used by BlockViewModel.detectStaleBlock

    func testResidualHostsContainsMarker() {
        // Sanity: confirms the marker-containment check BlockViewModel.detectStaleBlock
        // uses would fire on residualHosts but not on cleaned output.
        XCTAssertTrue(residualHosts.contains(MonkModeConstants.marker))
        let cleaned = HostsGenerator.cleanHostsContent(residualHosts)
        XCTAssertFalse(cleaned.contains(MonkModeConstants.marker))
    }
}
