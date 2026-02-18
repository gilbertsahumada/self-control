import XCTest
@testable import BlockSitesCore

final class BlockConfigurationTests: XCTestCase {

    // MARK: - Encode/Decode Round-Trip

    func testEncodeDecodeRoundTrip() throws {
        let start = Date()
        let end = start.addingTimeInterval(3600)
        let config = BlockConfiguration(sites: ["example.com", "test.org"], startTime: start, endTime: end)

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(BlockConfiguration.self, from: data)

        XCTAssertEqual(decoded.sites, config.sites)
        XCTAssertEqual(decoded.startTime.timeIntervalSince1970, config.startTime.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(decoded.endTime.timeIntervalSince1970, config.endTime.timeIntervalSince1970, accuracy: 0.001)
    }

    // MARK: - JSON Format

    func testJSONContainsExpectedKeys() throws {
        let config = BlockConfiguration(
            sites: ["facebook.com"],
            startTime: Date(),
            endTime: Date().addingTimeInterval(7200)
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertNotNil(json?["sites"])
        XCTAssertNotNil(json?["startTime"])
        XCTAssertNotNil(json?["endTime"])
    }

    func testSitesArrayInJSON() throws {
        let config = BlockConfiguration(
            sites: ["a.com", "b.com", "c.com"],
            startTime: Date(),
            endTime: Date().addingTimeInterval(60)
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        let sites = json?["sites"] as? [String]
        XCTAssertEqual(sites, ["a.com", "b.com", "c.com"])
    }

    // MARK: - Date Serialization

    func testDateSerializationPreservesValues() throws {
        let start = Date(timeIntervalSince1970: 1700000000)
        let end = Date(timeIntervalSince1970: 1700003600)
        let config = BlockConfiguration(sites: ["test.com"], startTime: start, endTime: end)

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(BlockConfiguration.self, from: data)

        XCTAssertEqual(decoded.startTime.timeIntervalSince1970, 1700000000, accuracy: 0.001)
        XCTAssertEqual(decoded.endTime.timeIntervalSince1970, 1700003600, accuracy: 0.001)
    }

    func testEmptySitesArray() throws {
        let config = BlockConfiguration(sites: [], startTime: Date(), endTime: Date())

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(BlockConfiguration.self, from: data)

        XCTAssertEqual(decoded.sites, [])
    }
}
