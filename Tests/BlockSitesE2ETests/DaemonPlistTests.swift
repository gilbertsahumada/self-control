import XCTest
@testable import MonkModeCore

/// Validates the launch-daemon plists produced by `DaemonPlistBuilder`.
///
/// We parse each plist with `PropertyListSerialization` to guarantee the XML
/// is structurally valid, and then poke at individual keys to make sure the
/// enforcer and cleanup daemons are configured the way the install script
/// and the rest of the app expects.
final class DaemonPlistTests: XCTestCase {

    // MARK: - Parsing helper

    private func parsePlist(_ xml: String, file: StaticString = #file, line: UInt = #line) -> [String: Any]? {
        guard let data = xml.data(using: .utf8) else {
            XCTFail("plist string is not valid UTF-8", file: file, line: line)
            return nil
        }
        do {
            var format = PropertyListSerialization.PropertyListFormat.xml
            let parsed = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: &format
            )
            guard let dict = parsed as? [String: Any] else {
                XCTFail("plist is not a dictionary", file: file, line: line)
                return nil
            }
            return dict
        } catch {
            XCTFail("Failed to parse plist: \(error)", file: file, line: line)
            return nil
        }
    }

    // MARK: - Enforcer plist

    func testEnforcerPlistParsesAsValidXML() {
        let xml = DaemonPlistBuilder.buildEnforcerDaemonPlist()
        XCTAssertNotNil(parsePlist(xml))
    }

    func testEnforcerPlistLabel() {
        let xml = DaemonPlistBuilder.buildEnforcerDaemonPlist()
        guard let dict = parsePlist(xml) else { return }
        XCTAssertEqual(dict["Label"] as? String, MonkModeConstants.enforcerDaemonLabel)
    }

    func testEnforcerPlistProgramArgumentsPointsAtInstallPath() {
        let xml = DaemonPlistBuilder.buildEnforcerDaemonPlist()
        guard let dict = parsePlist(xml) else { return }
        let args = dict["ProgramArguments"] as? [String]
        XCTAssertEqual(args?.first, MonkModeConstants.enforcerInstallPath)
    }

    func testEnforcerPlistStartIntervalIs60() {
        let xml = DaemonPlistBuilder.buildEnforcerDaemonPlist()
        guard let dict = parsePlist(xml) else { return }
        XCTAssertEqual(dict["StartInterval"] as? Int, 60)
    }

    func testEnforcerPlistRunAtLoadIsTrue() {
        let xml = DaemonPlistBuilder.buildEnforcerDaemonPlist()
        guard let dict = parsePlist(xml) else { return }
        XCTAssertEqual(dict["RunAtLoad"] as? Bool, true)
    }

    func testEnforcerPlistLogPaths() {
        let xml = DaemonPlistBuilder.buildEnforcerDaemonPlist()
        guard let dict = parsePlist(xml) else { return }
        XCTAssertEqual(dict["StandardOutPath"] as? String, MonkModeConstants.enforcerLogPath)
        XCTAssertEqual(dict["StandardErrorPath"] as? String, MonkModeConstants.enforcerLogPath)
    }

    // MARK: - Cleanup plist

    func testCleanupPlistParsesAsValidXML() {
        let xml = DaemonPlistBuilder.buildCleanupDaemonPlist(endTime: Date())
        XCTAssertNotNil(parsePlist(xml))
    }

    func testCleanupPlistLabel() {
        let xml = DaemonPlistBuilder.buildCleanupDaemonPlist(endTime: Date())
        guard let dict = parsePlist(xml) else { return }
        XCTAssertEqual(dict["Label"] as? String, MonkModeConstants.cleanupDaemonLabel)
    }

    func testCleanupPlistProgramArgumentsPointsAtInstallPath() {
        let xml = DaemonPlistBuilder.buildCleanupDaemonPlist(endTime: Date())
        guard let dict = parsePlist(xml) else { return }
        let args = dict["ProgramArguments"] as? [String]
        XCTAssertEqual(args?.first, MonkModeConstants.enforcerInstallPath)
    }

    func testCleanupPlistRunAtLoadIsFalse() {
        let xml = DaemonPlistBuilder.buildCleanupDaemonPlist(endTime: Date())
        guard let dict = parsePlist(xml) else { return }
        XCTAssertEqual(dict["RunAtLoad"] as? Bool, false,
                       "Cleanup must not fire on load — only at endTime")
    }

    func testCleanupPlistStartCalendarIntervalMatchesEndTime() {
        // Pick a date with distinct month/day/hour/minute so any component swap
        // would be detected. 2026-07-14 09:37 local time.
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 14
        components.hour = 9
        components.minute = 37
        components.second = 0
        let calendar = Calendar(identifier: .gregorian)
        guard let endTime = calendar.date(from: components) else {
            XCTFail("Could not construct test date")
            return
        }

        let xml = DaemonPlistBuilder.buildCleanupDaemonPlist(endTime: endTime)
        guard let dict = parsePlist(xml) else { return }
        guard let calendarInterval = dict["StartCalendarInterval"] as? [String: Any] else {
            XCTFail("Missing StartCalendarInterval")
            return
        }

        XCTAssertEqual(calendarInterval["Month"] as? Int, 7)
        XCTAssertEqual(calendarInterval["Day"] as? Int, 14)
        XCTAssertEqual(calendarInterval["Hour"] as? Int, 9)
        XCTAssertEqual(calendarInterval["Minute"] as? Int, 37)
    }

    func testCleanupPlistStartCalendarIntervalForEndOfYear() {
        // Edge case: December 31st at 23:59 — makes sure we do not clamp or roll over.
        var components = DateComponents()
        components.year = 2026
        components.month = 12
        components.day = 31
        components.hour = 23
        components.minute = 59
        let calendar = Calendar(identifier: .gregorian)
        guard let endTime = calendar.date(from: components) else {
            XCTFail("Could not construct test date")
            return
        }

        let xml = DaemonPlistBuilder.buildCleanupDaemonPlist(endTime: endTime)
        guard let dict = parsePlist(xml) else { return }
        guard let calendarInterval = dict["StartCalendarInterval"] as? [String: Any] else {
            XCTFail("Missing StartCalendarInterval")
            return
        }

        XCTAssertEqual(calendarInterval["Month"] as? Int, 12)
        XCTAssertEqual(calendarInterval["Day"] as? Int, 31)
        XCTAssertEqual(calendarInterval["Hour"] as? Int, 23)
        XCTAssertEqual(calendarInterval["Minute"] as? Int, 59)
    }

    func testCleanupPlistLogPaths() {
        let xml = DaemonPlistBuilder.buildCleanupDaemonPlist(endTime: Date())
        guard let dict = parsePlist(xml) else { return }
        XCTAssertEqual(dict["StandardOutPath"] as? String, MonkModeConstants.enforcerLogPath)
        XCTAssertEqual(dict["StandardErrorPath"] as? String, MonkModeConstants.enforcerLogPath)
    }

    // MARK: - Cross-plist sanity

    func testEnforcerAndCleanupPlistsHaveDifferentLabels() {
        let enforcer = DaemonPlistBuilder.buildEnforcerDaemonPlist()
        let cleanup = DaemonPlistBuilder.buildCleanupDaemonPlist(endTime: Date())
        guard let e = parsePlist(enforcer), let c = parsePlist(cleanup) else { return }
        XCTAssertNotEqual(e["Label"] as? String, c["Label"] as? String)
    }

    func testEnforcerPlistDoesNotHaveStartCalendarInterval() {
        let xml = DaemonPlistBuilder.buildEnforcerDaemonPlist()
        guard let dict = parsePlist(xml) else { return }
        XCTAssertNil(dict["StartCalendarInterval"],
                     "Enforcer runs on StartInterval, not a calendar trigger")
    }

    func testCleanupPlistDoesNotHaveStartInterval() {
        let xml = DaemonPlistBuilder.buildCleanupDaemonPlist(endTime: Date())
        guard let dict = parsePlist(xml) else { return }
        XCTAssertNil(dict["StartInterval"],
                     "Cleanup is one-shot via StartCalendarInterval, not a periodic StartInterval")
    }
}
