import Foundation

class FirewallManager {
    static let shared = FirewallManager()

    private let pfRulesPath = "/etc/pf.anchors/com.blocksites"
    private let pfConfPath = "/etc/pf.conf"
    private let ipCachePath = "/Library/Application Support/BlockSites/ip_cache.json"

    struct IPCache: Codable {
        var ips: [String: [String]]  // domain -> [IPs]
        var lastUpdated: Date
    }

    func blockSitesWithFirewall(_ sites: [String]) throws {
        // Resolve domains to IPs
        var domainIPs: [String: [String]] = [:]

        for site in sites {
            if let ips = try? resolveIPs(for: site) {
                domainIPs[site] = ips
            }
        }

        // Create pf anchor rules
        var rules = "# BlockSites firewall rules\n"

        for (_, ips) in domainIPs {
            for ip in ips {
                rules += "block drop quick from any to \(ip)\n"
                rules += "block drop quick from \(ip) to any\n"
            }
        }

        // Write rules to anchor file
        try rules.write(toFile: pfRulesPath, atomically: true, encoding: .utf8)

        // Enable the anchor in pf.conf if not already there
        try ensurePfAnchor()

        // Load the rules
        try loadFirewallRules()

        // Cache IPs for enforcer
        let cache = IPCache(ips: domainIPs, lastUpdated: Date())
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(cache) {
            try? data.write(to: URL(fileURLWithPath: ipCachePath))
        }
    }

    func removeFirewallRules() throws {
        // Remove the anchor file
        try? FileManager.default.removeItem(atPath: pfRulesPath)

        // Remove anchor references from pf.conf
        removePfAnchor()

        // Reload pf to clear rules
        try runCommand("/sbin/pfctl", args: ["-f", "/etc/pf.conf"])
    }

    private func removePfAnchor() {
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

    private func resolveIPs(for domain: String) throws -> [String] {
        var ips: [String] = []

        // Use host command to get IPs
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/host")
        process.arguments = [domain, "8.8.8.8"]  // Use Google DNS to avoid /etc/hosts

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            // Parse output for IPv4 addresses
            let lines = output.components(separatedBy: .newlines)
            for line in lines {
                if line.contains("has address") {
                    let parts = line.components(separatedBy: " ")
                    if let ip = parts.last {
                        ips.append(ip)
                    }
                }
            }
        }

        return ips
    }

    private func ensurePfAnchor() throws {
        let anchorLine = "anchor \"com.blocksites\""
        let loadLine = "load anchor \"com.blocksites\" from \"/etc/pf.anchors/com.blocksites\""

        guard let pfConf = try? String(contentsOfFile: pfConfPath, encoding: .utf8) else {
            return
        }

        // Check if anchor already exists
        if pfConf.contains(anchorLine) {
            return
        }

        // Add anchor at the end
        var newConf = pfConf
        if !newConf.hasSuffix("\n") {
            newConf += "\n"
        }
        newConf += "\n# BlockSites anchor\n"
        newConf += anchorLine + "\n"
        newConf += loadLine + "\n"

        try newConf.write(toFile: pfConfPath, atomically: true, encoding: .utf8)
    }

    private func loadFirewallRules() throws {
        // Enable pf if not enabled
        try? runCommand("/sbin/pfctl", args: ["-e"])

        // Reload pf configuration
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
