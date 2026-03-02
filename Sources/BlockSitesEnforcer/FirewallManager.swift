import Foundation
import SelfControlCore

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
        // 1. Clean pf.conf FIRST (while anchor file still exists, so pfctl reload works)
        removePfAnchor()

        // 2. Disable pf to restore normal networking
        do {
            try runCommand("/sbin/pfctl", args: ["-d"])
        } catch {
            log("Warning: failed to disable pf: \(error)")
        }

        // 3. Reload clean pf.conf
        do {
            try runCommand("/sbin/pfctl", args: ["-f", "/etc/pf.conf"])
        } catch {
            log("Warning: failed to reload pf.conf: \(error)")
        }

        // 4. Delete anchor file last (pf.conf no longer references it)
        try? FileManager.default.removeItem(atPath: pfRulesPath)
    }

    private func removePfAnchor() {
        let pfConfPath = "/etc/pf.conf"
        guard let pfConf = try? String(contentsOfFile: pfConfPath, encoding: .utf8) else {
            log("Error: could not read \(pfConfPath)")
            return
        }

        let (cleanedConf, didChange) = PfConfCleaner.cleanPfConfContent(pfConf)
        guard didChange else { return }

        do {
            try cleanedConf.write(toFile: pfConfPath, atomically: true, encoding: .utf8)
        } catch {
            // Atomic write failed — retry with non-atomic write
            log("Warning: atomic write to pf.conf failed (\(error)), retrying non-atomic")
            do {
                try cleanedConf.write(toFile: pfConfPath, atomically: false, encoding: .utf8)
            } catch {
                log("Error: failed to clean pf.conf: \(error)")
            }
        }
    }

    private func log(_ message: String) {
        let logPath = "/Library/Application Support/BlockSites/enforcer.log"
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] \(message)\n"
        if let handle = FileHandle(forWritingAtPath: logPath) {
            handle.seekToEndOfFile()
            handle.write(entry.data(using: .utf8) ?? Data())
            handle.closeFile()
        }
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
