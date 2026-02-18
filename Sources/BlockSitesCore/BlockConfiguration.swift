import Foundation

public struct BlockConfiguration: Codable {
    public let sites: [String]
    public let startTime: Date
    public let endTime: Date

    public init(sites: [String], startTime: Date, endTime: Date) {
        self.sites = sites
        self.startTime = startTime
        self.endTime = endTime
    }
}
