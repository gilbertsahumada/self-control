import Foundation

class FirewallManager {
    static let shared = FirewallManager()

    private let pfRulesPath = "/etc/pf.anchors/com.blocksites"
    private let ipCachePath = "/Library/Application Support/BlockSites/ip_cache.json"

    struct IPCache: Codable {
        var ips: [String: [String]]
        var cidrs: [String: [String]]?
        var dohIPs: [String]?
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

        // Per-IP rules
        for (_, ips) in cache.ips {
            for ip in ips {
                rules += "block drop quick from any to \(ip)\n"
                rules += "block drop quick from \(ip) to any\n"
            }
        }

        // CIDR range rules
        if let cidrs = cache.cidrs {
            for (_, cidrList) in cidrs {
                for cidr in cidrList {
                    rules += "block drop quick from any to \(cidr)\n"
                    rules += "block drop quick from \(cidr) to any\n"
                }
            }
        }

        // DoH blocking rules (port 443 only)
        if let dohIPs = cache.dohIPs {
            for ip in dohIPs {
                rules += "block drop quick proto tcp from any to \(ip) port 443\n"
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
