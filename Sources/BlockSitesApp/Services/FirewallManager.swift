import Foundation
import BlockSitesCore

enum FirewallManager {
    /// IPCache must match the enforcer's IPCache struct exactly for JSON compatibility.
    struct IPCache: Codable {
        var ips: [String: [String]]
        var cidrs: [String: [String]]?
        var dohIPs: [String]?
        var lastUpdated: Date
    }

    /// Resolves IPs for a single domain using the `host` command.
    /// Runs without root — just DNS lookups.
    static func resolveIPs(for domain: String) -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/host")
        process.arguments = [domain, "8.8.8.8"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        var ips: [String] = []
        for line in output.components(separatedBy: .newlines) {
            if line.contains("has address") {
                if let ip = line.components(separatedBy: " ").last {
                    ips.append(ip)
                }
            }
        }
        return ips
    }

    /// Resolves all IPs for a list of sites and builds the pf anchor rules + IP cache in memory.
    /// Returns (rulesContent, ipCacheData).
    static func generateFirewallData(for sites: [String]) -> (rules: String, cacheData: Data?) {
        var domainIPs: [String: [String]] = [:]
        var domainCIDRs: [String: [String]] = [:]

        for site in sites {
            var allIPs: [String] = []
            let domainsToResolve = DomainExpander.expandDomainsForFirewall(site)
            for domain in domainsToResolve {
                let ips = resolveIPs(for: domain)
                allIPs.append(contentsOf: ips)
            }
            domainIPs[site] = Array(Set(allIPs))

            let cidrs = DomainExpander.cidrRanges(for: site)
            if !cidrs.isEmpty {
                domainCIDRs[site] = cidrs
            }
        }

        // Build pf anchor rules
        var rules = "# BlockSites firewall rules\n"

        for (_, ips) in domainIPs {
            for ip in ips {
                rules += "block drop quick from any to \(ip)\n"
                rules += "block drop quick from \(ip) to any\n"
            }
        }

        for (_, cidrs) in domainCIDRs {
            for cidr in cidrs {
                rules += "block drop quick from any to \(cidr)\n"
                rules += "block drop quick from \(cidr) to any\n"
            }
        }

        for ip in DomainExpander.dohIPs {
            rules += "block drop quick proto tcp from any to \(ip) port 443\n"
        }

        // Build IP cache JSON
        let cache = IPCache(
            ips: domainIPs,
            cidrs: domainCIDRs.isEmpty ? nil : domainCIDRs,
            dohIPs: DomainExpander.dohIPs,
            lastUpdated: Date()
        )
        let cacheData = try? JSONEncoder().encode(cache)

        return (rules, cacheData)
    }
}
