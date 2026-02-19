import XCTest
@testable import SelfControlCore

final class TimeFormatterTests: XCTestCase {

    // MARK: - formatDuration

    func testFormatDurationHoursMinutesSeconds() {
        let result = TimeFormatter.formatDuration(5025) // 1h 23m 45s
        XCTAssertEqual(result, "1h 23m 45s")
    }

    func testFormatDurationMinutesSeconds() {
        let result = TimeFormatter.formatDuration(754) // 12m 34s
        XCTAssertEqual(result, "12m 34s")
    }

    func testFormatDurationSecondsOnly() {
        let result = TimeFormatter.formatDuration(45)
        XCTAssertEqual(result, "45s")
    }

    func testFormatDurationZeroSeconds() {
        let result = TimeFormatter.formatDuration(0)
        XCTAssertEqual(result, "0s")
    }

    func testFormatDurationExactHour() {
        let result = TimeFormatter.formatDuration(3600)
        XCTAssertEqual(result, "1h 0m 0s")
    }

    func testFormatDurationLargeValue() {
        let result = TimeFormatter.formatDuration(86400) // 24 hours
        XCTAssertEqual(result, "24h 0m 0s")
    }

    // MARK: - formatDurationShort

    func testFormatDurationShortHoursAndMinutes() {
        let result = TimeFormatter.formatDurationShort(5400) // 1h 30m
        XCTAssertEqual(result, "1h 30m")
    }

    func testFormatDurationShortHoursOnly() {
        let result = TimeFormatter.formatDurationShort(7200) // 2h
        XCTAssertEqual(result, "2h")
    }

    func testFormatDurationShortMinutesOnly() {
        let result = TimeFormatter.formatDurationShort(1800) // 30m
        XCTAssertEqual(result, "30m")
    }

    func testFormatDurationShortZero() {
        let result = TimeFormatter.formatDurationShort(0)
        XCTAssertEqual(result, "0m")
    }

    func testFormatDurationShortIgnoresSeconds() {
        // 1h 30m 45s should show as "1h 30m"
        let result = TimeFormatter.formatDurationShort(5445)
        XCTAssertEqual(result, "1h 30m")
    }

    func testFormatDurationShortLargeValue() {
        let result = TimeFormatter.formatDurationShort(86400) // 24h 0m → "24h"
        XCTAssertEqual(result, "24h")
    }
}
