import XCTest
@testable import MonkModeCore

/// Pins down the concrete values of `MonkModeConstants` so accidental
/// renames or drifts between the app, enforcer, and install scripts are
/// caught at test time rather than in production.
final class ConstantsTests: XCTestCase {

    // MARK: - Marker

    func testMarkerValue() {
        XCTAssertEqual(MonkModeConstants.marker, "# MONKMODE")
    }

    func testMarkerIsNonEmpty() {
        XCTAssertFalse(MonkModeConstants.marker.isEmpty)
    }

    // MARK: - Daemon labels

    func testEnforcerDaemonLabel() {
        XCTAssertEqual(MonkModeConstants.enforcerDaemonLabel, "com.monkmode.enforcer")
    }

    func testCleanupDaemonLabel() {
        XCTAssertEqual(MonkModeConstants.cleanupDaemonLabel, "com.monkmode.cleanup")
    }

    func testDaemonLabelsAreDistinct() {
        XCTAssertNotEqual(MonkModeConstants.enforcerDaemonLabel,
                          MonkModeConstants.cleanupDaemonLabel)
    }

    // MARK: - Install paths

    func testEnforcerInstallPath() {
        XCTAssertEqual(MonkModeConstants.enforcerInstallPath,
                       "/usr/local/bin/monkmode-enforcer")
    }

    func testEnforcerDaemonPlistPath() {
        XCTAssertEqual(MonkModeConstants.enforcerDaemonPlistPath,
                       "/Library/LaunchDaemons/com.monkmode.enforcer.plist")
    }

    func testCleanupDaemonPlistPath() {
        XCTAssertEqual(MonkModeConstants.cleanupDaemonPlistPath,
                       "/Library/LaunchDaemons/com.monkmode.cleanup.plist")
    }

    func testPlistPathContainsCorrespondingLabel() {
        XCTAssertTrue(MonkModeConstants.enforcerDaemonPlistPath
            .contains(MonkModeConstants.enforcerDaemonLabel))
        XCTAssertTrue(MonkModeConstants.cleanupDaemonPlistPath
            .contains(MonkModeConstants.cleanupDaemonLabel))
    }

    // MARK: - PF anchor

    func testPfAnchorName() {
        XCTAssertEqual(MonkModeConstants.pfAnchorName, "com.monkmode")
    }

    func testPfAnchorPathEndsWithAnchorName() {
        XCTAssertTrue(MonkModeConstants.pfAnchorPath.hasSuffix("com.monkmode"),
                      "pfAnchorPath should end with the anchor name, got \(MonkModeConstants.pfAnchorPath)")
    }

    func testPfAnchorPath() {
        XCTAssertEqual(MonkModeConstants.pfAnchorPath, "/etc/pf.anchors/com.monkmode")
    }

    // MARK: - System paths

    func testHostsPath() {
        XCTAssertEqual(MonkModeConstants.hostsPath, "/etc/hosts")
    }

    func testPfConfPath() {
        XCTAssertEqual(MonkModeConstants.pfConfPath, "/etc/pf.conf")
    }

    func testSupportDir() {
        XCTAssertEqual(MonkModeConstants.supportDir,
                       "/Library/Application Support/MonkMode")
    }

    // MARK: - Derived paths rooted in supportDir

    func testConfigFilePathUsesSupportDir() {
        XCTAssertTrue(MonkModeConstants.configFilePath.hasPrefix(MonkModeConstants.supportDir))
        XCTAssertTrue(MonkModeConstants.configFilePath.hasSuffix("config.json"))
    }

    func testIpCachePathUsesSupportDir() {
        XCTAssertTrue(MonkModeConstants.ipCachePath.hasPrefix(MonkModeConstants.supportDir))
        XCTAssertTrue(MonkModeConstants.ipCachePath.hasSuffix("ip_cache.json"))
    }

    func testHostsBackupPathUsesSupportDir() {
        XCTAssertTrue(MonkModeConstants.hostsBackupPath.hasPrefix(MonkModeConstants.supportDir))
        XCTAssertTrue(MonkModeConstants.hostsBackupPath.hasSuffix("hosts.backup"))
    }

    func testStateFilePathUsesSupportDir() {
        XCTAssertTrue(MonkModeConstants.stateFilePath.hasPrefix(MonkModeConstants.supportDir))
    }

    func testEnforcerLogPathUsesSupportDir() {
        XCTAssertTrue(MonkModeConstants.enforcerLogPath.hasPrefix(MonkModeConstants.supportDir))
        XCTAssertTrue(MonkModeConstants.enforcerLogPath.hasSuffix(".log"))
    }

    func testInstallLogPathUsesSupportDir() {
        XCTAssertTrue(MonkModeConstants.installLogPath.hasPrefix(MonkModeConstants.supportDir))
        XCTAssertTrue(MonkModeConstants.installLogPath.hasSuffix(".log"))
    }

    // MARK: - All strings non-empty

    func testAllConstantsAreNonEmpty() {
        let all: [String] = [
            MonkModeConstants.marker,
            MonkModeConstants.enforcerDaemonLabel,
            MonkModeConstants.cleanupDaemonLabel,
            MonkModeConstants.pfAnchorName,
            MonkModeConstants.supportDir,
            MonkModeConstants.hostsPath,
            MonkModeConstants.pfConfPath,
            MonkModeConstants.pfAnchorPath,
            MonkModeConstants.enforcerInstallPath,
            MonkModeConstants.enforcerDaemonPlistPath,
            MonkModeConstants.cleanupDaemonPlistPath,
            MonkModeConstants.configFilePath,
            MonkModeConstants.ipCachePath,
            MonkModeConstants.hostsBackupPath,
            MonkModeConstants.stateFilePath,
            MonkModeConstants.enforcerLogPath,
            MonkModeConstants.installLogPath
        ]
        for value in all {
            XCTAssertFalse(value.isEmpty, "constant should be non-empty")
        }
    }
}
