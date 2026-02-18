import Foundation

class FirewallManager {
    static let shared = FirewallManager()

    private let pfRulesPath = "/etc/pf.anchors/com.blocksites"
    private let ipCachePath = "/Library/Application Support/BlockSites/ip_cache.json"

    struct IPCache: Codable {
        var ips: [String: [String]]
        var lastUpdated: Date
    }

    func reapplyFirewallRules() {
        // Load cached IPs
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: ipCachePath)),
              let cache = try? JSONDecoder().decode(IPCache.self, from: data) else {
            return
        }

        // Recreate rules from cache
        var rules = "# BlockSites firewall rules\n"

        for (_, ips) in cache.ips {
            for ip in ips {
                rules += "block drop quick from any to \(ip)\n"
                rules += "block drop quick from \(ip) to any\n"
            }
        }

        // Write and reload
        try? rules.write(toFile: pfRulesPath, atomically: true, encoding: .utf8)
        try? loadFirewallRules()
    }

    func removeFirewallRules() {
        try? FileManager.default.removeItem(atPath: pfRulesPath)

        // Remove anchor references from pf.conf
        removePfAnchor()

        try? runCommand("/sbin/pfctl", args: ["-f", "/etc/pf.conf"])
    }

    private func removePfAnchor() {
        let pfConfPath = "/etc/pf.conf"
        guard let pfConf = try? String(contentsOfFile: pfConfPath, encoding: .utf8) else {
            return
        }

        let lines = pfConf.components(separatedBy: .newlines)
        let cleanedLines = lines.filter { line in
            !line.contains("# BlockSites anchor") &&
            !line.contains("anchor \"com.blocksites\"") &&
            !line.contains("load anchor \"com.blocksites\"")
        }

        let cleanedConf = cleanedLines.joined(separator: "\n")
        try? cleanedConf.write(toFile: pfConfPath, atomically: true, encoding: .utf8)
    }

    private func loadFirewallRules() throws {
        try? runCommand("/sbin/pfctl", args: ["-e"])
        try runCommand("/sbin/pfctl", args: ["-f", "/etc/pf.conf"])
    }

    private func runCommand(_ path: String, args: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        try process.run()
        process.waitUntilExit()
    }
}
