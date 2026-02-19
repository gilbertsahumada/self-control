import Foundation
import SelfControlCore

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

    /// Resolves IPs for multiple domains concurrently using TaskGroup.
    static func resolveIPsConcurrently(for domains: [String]) async -> [String] {
        await withTaskGroup(of: [String].self) { group in
            for domain in domains {
                group.addTask {
                    resolveIPs(for: domain)
                }
            }
            var allIPs: [String] = []
            for await ips in group {
                allIPs.append(contentsOf: ips)
            }
            return allIPs
        }
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

        return buildFirewallResponse(domainIPs: domainIPs, domainCIDRs: domainCIDRs)
    }

    /// Async version that resolves IPs concurrently for better performance.
    static func generateFirewallDataAsync(for sites: [String]) async -> (rules: String, cacheData: Data?) {
        var domainIPs: [String: [String]] = [:]
        var domainCIDRs: [String: [String]] = [:]

        await withTaskGroup(of: (String, [String]).self) { group in
            for site in sites {
                let domainsToResolve = DomainExpander.expandDomainsForFirewall(site)
                group.addTask {
                    let allIPs = await self.resolveIPsConcurrently(for: domainsToResolve)
                    return (site, Array(Set(allIPs)))
                }
            }

            for await (site, ips) in group {
                domainIPs[site] = ips
            }
        }

        for site in sites {
            let cidrs = DomainExpander.cidrRanges(for: site)
            if !cidrs.isEmpty {
                domainCIDRs[site] = cidrs
            }
        }

        return buildFirewallResponse(domainIPs: domainIPs, domainCIDRs: domainCIDRs)
    }

    private static func buildFirewallResponse(domainIPs: [String: [String]], domainCIDRs: [String: [String]]) -> (rules: String, cacheData: Data?) {
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
