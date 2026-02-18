import Foundation

struct BlockConfiguration: Codable {
    let sites: [String]
    let startTime: Date
    let endTime: Date
}
